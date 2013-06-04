package ufront.db;

import sys.db.Manager;
import spadm.TableInfos;
import ufront.db.Object;
import ufront.db.Relationship;
using StringTools;
using Lambda;

/**
* An extension of DBAdmin that co-operates better with ufront.db classes
* 
* Changes
*  - Ignore classes with @noTable metadata
*  - Find classes using CompileTime.getAllClasses() instead
*  - Check relationships and add ManyToMany tables
*
* It has a handler() static method that is used in the exact same way as spadm.Admin.handler
* for processing the actual requests.
*/
class DBAdmin extends spadm.Admin
{
	public var manyToManyTableNames:Array<String>;
	
	public function new()
	{
		super();
		manyToManyTableNames = [];
	}

	override function getTables() 
	{
		var tables:Array<TableInfos> = new Array();

		var classes = CompileTime.getAllClasses(Object);
		for (cl in classes)
		{
			addTable(tables, cl);
		}

		tables.sort(function(t1,t2) { return if( t1.name.toUpperCase() > t2.name.toUpperCase() ) 1 else if( t1.name.toUpperCase() < t2.name.toUpperCase() ) -1 else 0; });
		return tables;
	}

	@:access(spadm.TableInfos)
	function addTable(tables:Array<TableInfos>, model:Class<Dynamic>)
	{
		// If no RTTI, don't add
		if( haxe.rtti.Meta.getType(model).rtti == null ) return;

		// If @noTable metadata, don't add
		var m = haxe.rtti.Meta.getType(model);
		if ( Reflect.hasField(m, "noTable") ) return;

		// Search relations for ManyToMany tables
		var rels:Array<String> = Reflect.field(model, "hxRelationships");

		// Looking for osmething like: students,ManyToMany,app.coredata.model.Student
		// for (r in rels)
		// {
		// 	var parts = r.split(",");
		// 	switch (parts)
		// 	{
		// 		case [_,"ManyToMany",bClassName]:
		// 			var aClassName = Type.getClassName(model);
		// 			var tableName = ManyToMany.generateTableName(model, Type.resolveClass(bClassName));

		// 			// If we haven't already created this join table
		// 			if (manyToManyTableNames.has(tableName) == false)
		// 			{
		// 				// Keep track of it
		// 				manyToManyTableNames.push(tableName);

		// 				// Sys.println('$field:ManyToMany<$aClassName,$bClassName> = $tableName'.htmlEscape()+"<br/>");

		// 				// Create a TableInfos for Relationship, then change the table name - see how it goes...
		// 				var ti = new TableInfos( Type.getClassName(Relationship) );
		// 					// public var cl(default,null) : Class<Object>;
		// 					// public var name(default,null) : String;
		// 					// public var className(default,null) : String;
		// 					// public var manager : Manager<Object>;
		// 				Sys.println('${ti.name} ${ti.className} <br />');
		// 				ti.name = tableName;
		// 				tables.push(ti);
		// 			}
		// 		default:
		// 			// do nothing
		// 	}
		// }
		
		// Look for ManyToMany relations
		tables.push(new TableInfos(Type.getClassName(model)));
	}

	public static function handler( ?baseUrl:String ) 
	{
		Manager.initialize(); // make sure it's been done
		try {
			new DBAdmin().process(baseUrl);
		} catch( e : Dynamic ) {
			// rollback in case of multiple delete/update - no effect on DB struct changes
			// since they are done outside of transaction
			Manager.cnx.rollback();
			neko.Lib.print("<pre>");
			neko.Lib.print(Std.string(e));
			neko.Lib.print(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
			neko.Lib.print("</pre>");
		}
	}
}