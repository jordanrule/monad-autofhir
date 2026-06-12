{-# LANGUAGE OverloadedStrings #-}
module Autofhir.Types
  ( RunManifest(..)
  , Chunk(..)
  , JournalEntry(..)
  ) where

import Data.Aeson
import Data.Text (Text)
import Data.Time.Clock (UTCTime)

data RunManifest = RunManifest
  { runId :: Text
  , createdAt :: UTCTime
  } deriving (Show, Eq)

instance FromJSON RunManifest where
  parseJSON = withObject "RunManifest" $ \o ->
    RunManifest <$> o .: "runId" <*> o .: "createdAt"

instance ToJSON RunManifest where
  toJSON (RunManifest rid ct) = object ["runId" .= rid, "createdAt" .= ct]

data Chunk = Chunk
  { chunkId :: Text
  , payload :: Value
  } deriving (Show, Eq)

instance FromJSON Chunk where
  parseJSON = withObject "Chunk" $ \o ->
    Chunk <$> o .: "chunkId" <*> o .: "payload"

instance ToJSON Chunk where
  toJSON (Chunk cid pl) = object ["chunkId" .= cid, "payload" .= pl]

data JournalEntry = JournalEntry
  { jeTimestamp :: UTCTime
  , jeType :: Text
  , jePayload :: Value
  } deriving (Show, Eq)

instance FromJSON JournalEntry where
  parseJSON = withObject "JournalEntry" $ \o ->
    JournalEntry <$> o .: "timestamp" <*> o .: "type" <*> o .: "payload"

instance ToJSON JournalEntry where
  toJSON (JournalEntry ts t p) = object ["timestamp" .= ts, "type" .= t, "payload" .= p]

-- Event is the domain-level journal entry used for auditing and idempotency.
data Event = Event
  { evTimestamp :: UTCTime
  , evName :: Text
  , evPayload :: Value
  } deriving (Show, Eq)

instance FromJSON Event where
  parseJSON = withObject "Event" $ \o ->
    Event <$> o .: "timestamp" <*> o .: "name" <*> o .: "payload"

instance ToJSON Event where
  toJSON (Event ts n p) = object ["timestamp" .= ts, "name" .= n, "payload" .= p]

