module Main (main) where

import Autofhir.Env
import Autofhir.Coordinator
import Options.Applicative
import Data.Semigroup ((<>))

data Cmd = Cmd
  { runId :: FilePath
  , concurrency :: Int
  , copilotPath :: FilePath
  }

cmdParser :: Parser Cmd
cmdParser = Cmd
  <$> strOption (long "run" <> short 'r' <> metavar "RUN_ID" <> help "Run id directory under runs/")
  <*> option auto (long "concurrency" <> short 'c' <> help "Number of concurrent workers" <> value 2)
  <*> strOption (long "copilot" <> help "Path to copilot binary" <> value "copilot")

main :: IO ()
main = do
  cmd <- execParser (info (cmdParser <**> helper) (fullDesc <> progDesc "monad-autofhir coordinator"))
  let env = AppEnv
            { envRoot = "."
            , envRunId = runId cmd
            , envCopilot = copilotPath cmd
            }
  runApp env $ coordinator (concurrency cmd)

