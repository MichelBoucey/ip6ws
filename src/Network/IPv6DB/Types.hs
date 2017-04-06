{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE RecordWildCards       #-}

module Network.IPv6DB.Types where

import           Data.Aeson      as A
import qualified Data.Text       as T
import qualified Data.Vector     as V
import           Text.IPv6Addr

data Addresses = Addresses [IPv6Addr]

instance FromJSON Addresses where
  parseJSON (Array v) = do
    let rslts = fromJSON <$> V.toList v
    if all isSuccess rslts
      then pure (Addresses $ fromResult <$> rslts)
      else fail "Bad JSON Array Of IPv6 Addresses"
  parseJSON _         = fail "JSON Array Expected"

data Source = Source !Value deriving (Eq, Show)

instance ToJSON Source where
  toJSON (Source v) = v

instance FromJSON Source where
  parseJSON v = pure (Source v)

data Resource
  = Resource
      { list    :: !T.Text
      , address :: !IPv6Addr
      , ttl     :: !(Maybe Integer)
      , source  :: !Source
      }
  | ResourceError
      { list    :: !T.Text
      , address :: !IPv6Addr
      , error   :: !T.Text
      } 
  deriving (Eq, Show)

instance ToJSON Resource where
  toJSON Resource{..} =
    object
      [ "list"    .= list
      , "address" .= address
      , "ttl"     .= ttl
      , "source"  .= source
      ]
  toJSON ResourceError{..} =
    object
      [ "list"    .= list
      , "address" .= address
      , "error"   .= error
      ]

instance FromJSON Resource where
  parseJSON =
    withObject "resource" $
      \o -> do
        list    <- o .: "list"
        address <- do
          ma <- o .: "address"
          case maybeIPv6Addr ma of
            Just a  -> pure a
            Nothing -> fail "Not an IPv6 Address"
        ttl     <- o .:? "ttl"
        source  <- o .: "source"
        return Resource{..}

data Resources = Resources [Resource] deriving (Eq, Show)

instance ToJSON Resources where
  toJSON (Resources rs) =
    object [ ("resources", Array (V.fromList $ toJSON <$> rs)) ]

instance FromJSON Resources where
  parseJSON (Array v) = do
    let rsrcs = fromJSON <$> V.toList v
    if all isSuccess rsrcs
      then pure $ Resources (toRsrc <$> rsrcs)
      else fail "Malformed JSON Array Of Resources"
  parseJSON _         = fail "JSON Array Expected"

isSuccess :: Result a -> Bool
isSuccess (A.Success _) = True
isSuccess (A.Error _)   = False

toRsrc :: Result Resource -> Resource
toRsrc (A.Success r) = r
toRsrc (A.Error _)   = Prelude.error "Success value only"

fromResult :: Result a -> a
fromResult (A.Success e) = e
fromResult (A.Error _)   = Prelude.error "Success value only"

