package ufront.tasks;

import haxe.Json;
import ufront.db.Object;
import sys.db.Types;

@:table("_admintasklog")
class AdminTaskLog extends Object
{
	public var ts:SString<255>;
	public var task:SString<255>;

	public var output:SText;

	public function new(ts:AdminTaskSet, task:String, output:String)
	{
		super();

		this.ts = ts.taskSetName;
		this.task = task;
		this.output = output;
	}
}