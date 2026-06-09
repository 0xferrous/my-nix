let ConfigType =
      { base : List Text
      , init : Text
      , regInfo : Text
      }

let Config =
      { Type = ConfigType
      , toList =
          \(cfg : ConfigType) ->
            cfg.base # [ "init=${cfg.init}", "regInfo=${cfg.regInfo}" ]
      }

in  Config
