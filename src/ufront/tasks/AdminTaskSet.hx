package ufront.tasks;

import ufront.tasks.AdminTaskLog;
import haxe.ds.StringMap;
using Reflect;
using Lambda;
using Detox;

@:rtti
class AdminTaskSet
{
	public static var allTaskSets(get,null):List<AdminTaskSet>;

	public var taskSetName:String;
	public var taskSetTitle:String;
	public var taskSetDescription:String;
	public var taskSetInputs:List<String>;
	public var tasks:Array<Task>;

	var currentClass:Class<AdminTaskSet>;

	/** On instantiating the TaskSet, build up our list of tasks, including information from the database about when it was last run, and metadata with the names of tasks. */
	public function new()
	{
		tasks = [];
		currentClass = Type.getClass(this);
		taskSetName = Type.getClassName(currentClass);

		// Get all tasks, most recent first, and turn into an array (because order is important to us 
		// and we will iterate over this more than once...)
		var allTasksRun = AdminTaskLog.manager.search(true, { orderBy : -modified }).array();

		var classMeta = haxe.rtti.Meta.getType(currentClass);
		taskSetTitle = Reflect.hasField(classMeta, 'name') ? classMeta.name[0] : taskSetName;
		taskSetDescription = Reflect.hasField(classMeta, 'description') ? classMeta.description[0] : "";
		taskSetInputs = getTaskSetInputs();

		var fieldsMeta = haxe.rtti.Meta.getFields(currentClass);
		// Search every field that has metadata for @task, and add those fields to the taskSet
		for (fieldName in Reflect.fields(fieldsMeta))
		{
			var thisFieldMeta = Reflect.field(fieldsMeta, fieldName);
			if (Reflect.hasField(thisFieldMeta, 'task'))
			{
				var taskTitle = (thisFieldMeta.task != null) ? thisFieldMeta.task[0] : fieldName;
				var taskDescription = Reflect.hasField(thisFieldMeta, "description") ? thisFieldMeta.description[0] : "";
				var taskInputs = getTaskInputs(fieldName);

				// Look for any previous runs, and try to get the last date the task was run
				var previousRuns = allTasksRun.filter(function (taskLog) { return taskLog.task == fieldName && taskLog.ts == taskSetName; });
				var taskLastRun = (previousRuns.length > 0) ? previousRuns[0].modified : null;
				
				// Create the task for this field, add it to the list
				var task = {
					taskSet: taskSetName,
					taskSetTitle: taskSetTitle,
					name: fieldName,
					title: taskTitle,
					description: taskDescription,
					inputs: taskInputs,
					lastRun: taskLastRun
				};
				tasks.push(task);
			}
		}
	}

	public function run(name:String, arguments:Array<String>, ?liveOutput=false):AdminTaskLog
	{
		// Set up a custom trace
		var originalTraceFn = haxe.Log.trace;
		var output = new StringBuf();

		var print = function (string) {
			output.add(string + "\n");
			if (liveOutput)	Sys.println(string);
		}
		
		haxe.Log.trace = function (t:Dynamic, ?p:haxe.PosInfos) { 
			var f = p.fileName;
			var l = p.lineNumber;
			var msg = Std.string(t);
			if (p.customParams != null) msg = msg + ' ' + p.customParams.join(' ');
			print('$f[$l]: $msg');
		}

		// Header info for the output
		var tsInputsHash = new StringMap<String>();
		for (i in taskSetInputs)
		{
			var value = Reflect.getProperty(this, i);
			tsInputsHash.set(i, value);
		}
		print('Running task $name in $taskSetName');
		print('  with task arguments $arguments');
		print('  and task set arguments $tsInputsHash\n');

		// Run the actual command
		var result = Reflect.callMethod(this, Reflect.field(this, name), arguments);
		if (result != null)
		{
			print('\nRESULT: $result');
		}

		// Save an AdminTaskLog
		var log = new AdminTaskLog(this, name, output.toString());
		log.save();

		// Restore the original trace
		haxe.Log.trace = originalTraceFn;

		return log;
	}

	// 
	// Private methods that get data from RTTI and metadata
	//
	var cls:Class<Dynamic>;
	var rtti:String;
	var rttiXml:dtx.DOMCollection;

	function getRtti()
	{
		if (rttiXml == null)
		{
			cls = Type.getClass(this);
			rtti = untyped cls.__rtti;	
			rttiXml = rtti.parse();
		}
		return rttiXml;
	}

	public function getTaskSetInputs()
	{
		var inputs = getRtti().find('m[n=input]').parents().parents();
		var inputNames = inputs.map(function (elm) { return elm.tagName(); });
		return inputNames;
	}

	public function getTaskInputs(task:String)
	{
		var taskField = getRtti().find('$task m[n=task]').parents().parents();
		var argumentsText = taskField.find("f").attr("a");
		var arguments = (argumentsText == "") ? [] : argumentsText.split(":");
		return arguments;
	}

	static var _sets:List<AdminTaskSet> = null;
	static function get_allTaskSets()
	{
		if (_sets == null) 
		{
			CompileTime.importPackage("server.tasks");
			_sets = cast CompileTime.getAllClasses(AdminTaskSet).map(function (ts) { return Type.createInstance(ts, []); });
		}
		return _sets;
	}
}

typedef Task = {
	taskSet:String,
	taskSetTitle:String,
	name:String,
	title:String,
	description:String,
	inputs:Array<String>,
	?lastRun:Date
}