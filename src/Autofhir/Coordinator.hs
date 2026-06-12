{-# LANGUAGE OverloadedStrings #-}
module Autofhir.Coordinator
  ( coordinator
  ) where

import Autofhir.Env
import Autofhir.FS
import Autofhir.Types
import Autofhir.Proc

import Control.Concurrent.Async
import Control.Concurrent.STM
import Control.Monad
import Control.Monad.IO.Class
import Data.Aeson
import qualified Data.ByteString.Lazy as BL
import System.FilePath
import System.Directory
import Autofhir.Hash (sha256Value)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Clock
import qualified Data.Set as Set

-- | Coordinator: polls pending chunks and processes them with a pool of workers.
coordinator :: Int -> AppM ()
coordinator concurrency = do
  ensureRunDirs
  q <- liftIO $ newTBQueueIO 1000
  files <- listPendingChunks
  liftIO $ atomically $ forM_ files (writeTBQueue q)
  -- launch workers bound to AppM environment
  env <- ask
  let launchWorker = async . runAppInIO env . runAppWorker q
  as <- replicateM concurrency (liftIO $ launchWorker)
  liftIO $ mapM_ wait as

runAppInIO :: AppEnv -> AppM a -> IO a
runAppInIO = runApp

runAppWorker :: TBQueue FilePath -> AppM ()
runAppWorker q = do
  env <- ask
  let loop = do
        mfp <- liftIO $ atomically $ do
          empty <- isEmptyTBQueue q
          if empty then retry else Just <$> readTBQueue q
        case mfp of
          Nothing -> return ()
          Just fp -> do
            -- move to running
            runningFp <- moveToRunning fp
            mchunk <- readChunkFile runningFp
            case mchunk of
              Nothing -> liftIO $ putStrLn $ "failed to parse chunk: " ++ runningFp
              Just chunk -> do
                -- compute idempotency key from chunk payload and check seen set
                let key = sha256Value (payload chunk)
                seenVar <- asks envSeen
                claimed <- liftIO $ atomically $ do
                  seen <- readTVar seenVar
                  if Set.member (T.unpack key) seen
                    then return False
                    else writeTVar seenVar (Set.insert (T.unpack key) seen) >> return True
                if not claimed
                  then do
                    now <- liftIO getCurrentTime
                    let ev = Event now "chunk-duplicate" (object ["chunkId" .= chunkId chunk, "key" .= key])
                    appendJournal ev
                    -- move duplicate to done with a short result
                    _ <- moveToDone runningFp (String "duplicate-skip")
                    liftIO $ putStrLn $ "Skipped duplicate " ++ runningFp
                  else do
                -- create a prompt file from chunk payload
                let promptPath = envRoot env </> envRunId env </> "requests" </> takeFileName runningFp
                liftIO $ createDirectoryIfMissing True (envRoot env </> envRunId env </> "requests")
                liftIO $ BL.writeFile promptPath (encode chunk)
                out <- runCopilot promptPath
                -- write result and move to done
                let resultVal = case decode out of
                                  Just v -> v
                                  Nothing -> String "copilot-output"
                _ <- moveToDone runningFp resultVal
                now <- liftIO getCurrentTime
                let ev = Event now "chunk-completed" (object ["chunkId" .= chunkId chunk])
                appendJournal ev
                liftIO $ putStrLn $ "Processed " ++ runningFp
            loop
  loop


