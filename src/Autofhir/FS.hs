{-# LANGUAGE OverloadedStrings #-}
module Autofhir.FS
  ( ensureRunDirs
  , runPath
  , pendingDir
  , runningDir
  , doneDir
  , listPendingChunks
  , readChunkFile
  , moveToRunning
  , moveToDone
  , appendJournal
  ) where

import Autofhir.Types
import Autofhir.Env
import Control.Monad.IO.Class
import Control.Monad.Reader
import System.Directory
import System.FilePath
import Data.Aeson
import qualified Data.ByteString.Lazy as BL
import Data.Time.Clock
import Control.Concurrent.STM
import Data.Time.Clock

runPath :: FilePath -> FilePath
runPath root = root

pendingDir :: FilePath -> FilePath
pendingDir runDir = runDir </> "chunks" </> "pending"

runningDir :: FilePath -> FilePath
runningDir runDir = runDir </> "chunks" </> "running"

doneDir :: FilePath -> FilePath
doneDir runDir = runDir </> "chunks" </> "done"

ensureRunDirs :: AppM ()
ensureRunDirs = do
  env <- ask
  let base = envRoot env </> envRunId env
  liftIO $ createDirectoryIfMissing True (pendingDir base)
  liftIO $ createDirectoryIfMissing True (runningDir base)
  liftIO $ createDirectoryIfMissing True (doneDir base)
  liftIO $ createDirectoryIfMissing True (base </> "results")
  liftIO $ createDirectoryIfMissing True (base </> "journal")

listPendingChunks :: AppM [FilePath]
listPendingChunks = do
  env <- ask
  let p = pendingDir (envRoot env </> envRunId env)
  exists <- liftIO $ doesDirectoryExist p
  if not exists then return [] else do
    files <- liftIO $ listDirectory p
    return $ map (p </>) $ filter (\f -> takeExtension f == ".json") files

readChunkFile :: FilePath -> AppM (Maybe Chunk)
readChunkFile fp = do
  bs <- liftIO $ BL.readFile fp
  return $ decode bs

moveToRunning :: FilePath -> AppM FilePath
moveToRunning fp = do
  env <- ask
  let base = envRoot env </> envRunId env
  let dest = runningDir base </> takeFileName fp
  liftIO $ renameFile fp dest
  return dest

moveToDone :: FilePath -> Value -> AppM FilePath
moveToDone runningFp result = do
  env <- ask
  now <- liftIO getCurrentTime
  let base = envRoot env </> envRunId env
  let dest = doneDir base </> takeFileName runningFp
  liftIO $ BL.writeFile dest (encode result)
  -- also write a simple results file under results/
  let resultsPath = base </> "results" </> takeFileName runningFp
  liftIO $ BL.writeFile resultsPath (encode result)
  appendJournal (JournalEntry now "chunk-done" result)
  return dest

appendJournal :: Event -> AppM ()
appendJournal ev = do
  env <- ask
  let base = envRoot env </> envRunId env
  let jdir = base </> "journal"
  liftIO $ createDirectoryIfMissing True jdir
  let jpath = jdir </> "journal.ndjson"
  let line = encode ev
  liftIO $ BL.appendFile jpath (line <> "\n")

