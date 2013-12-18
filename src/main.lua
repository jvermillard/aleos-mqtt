local sched = require 'sched'
local shell = require 'shell.telnet'
local MQTT = require 'mqtt_library'
local yajl = require 'yajl'

local dt = require 'devicetree'
-- Start a telnet server on port 1234
-- Once this program is started, you can start a Lua VM through telnet
-- using the following command: telnet localhost 1234
local function run_server()
  shell.init {
    address     = '0.0.0.0',
    port        = 1234,
    editmode    = "edit",
    historysize = 100 }
end

local deviceID
local password = require "password"
local host = "qa-trunk.airvantage.net"
local port = 1883
local mqtt_client

-- callback called when a MQTT message is recieved
local function callback (topic, message)
	if topic == deviceID.."/tasks/json" then
		print("TASK : " .. message)
		message = yajl.to_value(message)
		for _, task in ipairs(message) do
			if task.write  then
			    print("write not supported")
			elseif task.read then
	            local jsondata = "[{"
	            
				for idx, var in ipairs(task.read) do
					--print("ID to read : ".. var)
					if idx > 1 then
					    jsondata = jsondata.. ','
					end
					local data = dt.get("aleos."..var)
					--print("data "..var.." => ".. data)
					jsondata = jsondata.. '"' .. var .. '" : [{"timestamp": null, "value" : "'.. data ..'"}]'
					
				end
				print("Sending data: "..jsondata .."}]")
				mqtt_client:publish(deviceID .. "/messages/json",jsondata .."}]")
			end
		end
	end
end

local function init()
  dt.init()
  print("ALEOS version " .. dt.get("aleos.4"))
  
  deviceID = dt.get("config.agent.deviceId")
  print("Device ID " .. deviceID)
  
  MQTT.client.KEEP_ALIVE_TIME = 10
  mqtt_client = MQTT.client.create(host, port, callback)
  
  local connection = mqtt_client:connect(deviceID, deviceID, password)
  if(connection) then print ("CONNECTION: "..connection) end
  mqtt_client:subscribe({"launcher/*"})
  
  while true do
	local error_message = mqtt_client:handler()
	if (error_message) then print("ERROR : ".. error_message) end
    sched.wait(1)
  end
end


-- Start a thread for the MQTT client 
sched.run(init)

-- Create a thread to start the telnet server
sched.run(run_server)
  
-- Starting the scheduler main loop for running threads 
sched.loop()

