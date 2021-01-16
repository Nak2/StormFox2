StormFox.Setting.AddSV("temp_acc",5,nil,"Weather",0,20)
StormFox.Setting.AddSV("min_temp",-10,nil,"Weather")
StormFox.Setting.SetType( "min_temp", "temp" )
StormFox.Setting.AddSV("max_temp",20,nil, "Weather")
StormFox.Setting.SetType( "max_temp", "temp" )
StormFox.Setting.AddSV("auto_weather",true,nil, "Weather", 0, 1)
StormFox.Setting.AddSV("max_weathers_prday",3,nil, "Weather", 1, 8)

