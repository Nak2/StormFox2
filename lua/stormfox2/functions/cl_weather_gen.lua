StormFox.Setting.AddSV("temp_acc",5,"stormfox.temperature.acc","Weather",0,20)
StormFox.Setting.AddSV("min_temp",-10,"stormfox.temperature.min","Weather")
StormFox.Setting.SetType( "min_temp", "temp" )
StormFox.Setting.AddSV("max_temp",20,"stormfox.temperature.max", "Weather")
StormFox.Setting.SetType( "max_temp", "temp" )
StormFox.Setting.AddSV("auto_weahter",true,"stormfox.weather.auto", "Weather", 0, 1)
StormFox.Setting.AddSV("max_weathers_prday",3,"stormfox.weather.maxprday", "Weather", 1, 8)

