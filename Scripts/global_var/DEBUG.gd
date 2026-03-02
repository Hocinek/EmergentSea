extends Node
class_name DEBUG

const ENABLED = true
enum {
	INFO,
	ERROR,
	WARNING
	}

static func log(message:String,type=INFO):
	if(ENABLED == true):
		var txt : String = enum_to_str(type)+": "+message
		if(type == ERROR):
			push_error(txt)
		else:
			print(txt)

static func enum_to_str(type):
	if(type == INFO):
		return "INFO"
	elif(type == ERROR):
		return "ERROR"
	elif(type == WARNING):
		return "WARNING"
	else:
		return "UNDEFINED"
