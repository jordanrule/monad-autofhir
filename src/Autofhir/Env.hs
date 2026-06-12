{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Autofhir.Env
  ( AppEnv(..)
  , AppM
  , runApp
  ) where

import Control.Monad.IO.Class
import Control.Monad.Reader
import Control.Monad.Except

data AppEnv = AppEnv
  { envRoot :: FilePath
  , envRunId :: FilePath
  , envCopilot :: FilePath
  }

newtype AppM a = AppM { unApp :: ReaderT AppEnv IO a }
  deriving (Functor, Applicative, Monad, MonadIO, MonadReader AppEnv)

runApp :: AppEnv -> AppM a -> IO a
runApp env (AppM r) = runReaderT r env

