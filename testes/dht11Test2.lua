-- Read temperature and humidity data from DHT11 sensor.
-- Connect Data pin of DHT11 sesnor to PIN 3 (GPIO 0 - GPIO ZERO) of ESP8266 wifi module.
-- Learn: www.roboindia.com/tutorials
-- Ref-esp8266.com

pin = 3


Humidity = 0
HumidityDec=0
Temperature = 0
TemperatureDec=0
Checksum = 0
ChecksumTest=0

function configWifi()
     -- Configure Wi-Fi
     wifi.setmode(wifi.STATION)
     wifi.sta.config("piocorreia","wfpcapto41")
     wifi.sta.connect()

     print("Connecting to piocorreia")
     --print("IP is ".. wifi.sta.getip())
    --ip = wifi.sta.getip()

end

function getData()
     Humidity = 0
     HumidityDec=0
     Temperature = 0
     TemperatureDec=0
     Checksum = 0
     ChecksumTest=0


     bitStream = {}
     for j = 1, 40, 1 do
          bitStream[j]=0
     end
     bitlength=0

     gpio.mode(pin, gpio.OUTPUT)
     gpio.write(pin, gpio.LOW)
     tmr.delay(20000)
     --Use Markus Gritsch trick to speed up read/write on GPIO
     gpio_read=gpio.read
     gpio_write=gpio.write

     gpio.mode(pin, gpio.INPUT)

     --bus will always let up eventually, don't bother with timeout
     while (gpio_read(pin)==0 ) do end

     c=0
     while (gpio_read(pin)==1 and c<100) do c=c+1 end

     --bus will always let up eventually, don't bother with timeout
     while (gpio_read(pin)==0 ) do end

     c=0
     while (gpio_read(pin)==1 and c<100) do c=c+1 end

     --acquisition loop
     for j = 1, 40, 1 do
          while (gpio_read(pin)==1 and bitlength<10 ) do
               bitlength=bitlength+1
          end
          bitStream[j]=bitlength
          bitlength=0
          --bus will always let up eventually, don't bother with timeout
          while (gpio_read(pin)==0) do end
     end

     --DHT data acquired, processing it :-

     for i = 1, 8, 1 do
          if (bitStream[i+0] > 2) then
               Humidity = Humidity+2^(8-i)
          end
     end
     for i = 1, 8, 1 do
          if (bitStream[i+8] > 2) then
               HumidityDec = HumidityDec+2^(8-i)
          end
     end
     for i = 1, 8, 1 do
          if (bitStream[i+16] > 2) then
               Temperature = Temperature+2^(8-i)
          end
     end
     for i = 1, 8, 1 do
          if (bitStream[i+24] > 2) then
               TemperatureDec = TemperatureDec+2^(8-i)
          end
     end
     for i = 1, 8, 1 do
          if (bitStream[i+32] > 2) then
               Checksum = Checksum+2^(8-i)
          end
     end
     ChecksumTest=(Humidity+HumidityDec+Temperature+TemperatureDec) % 0xFF

     print ("Temperature: "..Temperature.."."..TemperatureDec)
     print ("Humidity: "..Humidity.."."..HumidityDec)
     print ("ChecksumReceived: "..Checksum)
     print ("ChecksumTest: "..ChecksumTest)
end

configWifi()

count = 0

while count < 10 do
     getData()
     node.dsleep(10000000)
     count=count+1
end

