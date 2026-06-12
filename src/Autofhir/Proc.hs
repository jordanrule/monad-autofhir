{-# LANGUAGE OverloadedStrings #-}
module Autofhir.Proc
  ( runCopilot
  ) where

import Autofhir.Env
import Control.Monad.IO.Class
import Control.Monad.Reader
import System.Process
import System.Exit
import qualified Data.ByteString.Lazy.Char8 as BL8

-- | Run the configured copilot binary with the given prompt file and return stdout as lazy bytestring.
runCopilot :: FilePath -> AppM BL8.ByteString
runCopilot promptFile = do
  env <- ask
  let cp = envCopilot env
  (exitCode, out, err) <- liftIO $ readProcessWithExitCode cp [promptFile] ""
  case exitCode of
    ExitSuccess -> return (BL8.pack out)
    ExitFailure c -> do
      liftIO $ putStrLn $ "copilot failed (exit " ++ show c ++ "): " ++ err
      return (BL8.pack out)

