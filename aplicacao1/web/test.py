from threading import Timer

def helloWorld(arg):
	print("Hello " + arg)

def createTimer():


	timerTest = Timer(5,helloWorld,["Clara"])
	timerTest.start()


if __name__ == '__main__':
	createTimer()