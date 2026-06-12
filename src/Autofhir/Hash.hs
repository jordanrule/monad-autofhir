{-# LANGUAGE OverloadedStrings #-}
module Autofhir.Hash
  ( sha256Value
  ) where

import Data.Aeson (Value, encode)
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as T
import Crypto.Hash (hashlazy, Digest, SHA256)

-- | Compute a SHA256 hex string for the JSON value's canonical bytes.
sha256Value :: Value -> Text
sha256Value v =
  let bs = encode v :: BL.ByteString
      digest = hashlazy bs :: Digest SHA256
  in T.pack (show digest)

