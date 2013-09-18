package ufront.ufadmin.controller;


import ufront.web.Controller;
#if macro 
	import haxe.macro.Expr;
#else
	import ufront.tasks.AdminTaskLog;
	import ufront.web.result.*;

	import ufront.ufadmin.view.UFAdminLayout;
	import ufront.ufadmin.view.AdminView;
	import ufront.ufadmin.view.TaskView;

	import ufront.auth.model.User;
	import ufront.auth.model.Permission;
	import ufront.auth.IAuthHandler;
	import ufront.web.error.PageNotFoundError;

	import dtx.layout.DetoxLayout;
	import haxe.ds.StringMap;
	import ufront.web.Dispatch;
	import haxe.web.Dispatch.DispatchConfig;
	using thx.util.CleverSort;
	using Detox;
	using Lambda;
#end

#if server
	class UFAdminController extends Controller
	{
		public static macro function addModule( name:ExprOf<String>, title:ExprOf<String>, controller:ExprOf<{}> ):ExprOf<haxe.web.Dispatch.DispatchConfig> {
			return macro UFAdminController.modules.set( $name, { title: $title, dispatch: ufront.web.Dispatch.make($controller) } );
		}

		#if !macro
			static var modules:StringMap<{ title:String, dispatch:DispatchConfig }> = new StringMap();
			public static var prefix = "/ufadmin";


			public function doDefault( ?module:String, ?d:Dispatch ) {
				checkAuth( context.auth );
				checkTablesExists();

				if ( module==null ) {
					var view = new AdminView();
					return new DetoxResult(view, null, getLayout());
				}
				else {
					if ( modules.exists(module) ) 
						return d.runtimeReturnDispatch( modules.get(module).dispatch );
					else 
						return throw new PageNotFoundError();
				}
			}

			public static function checkAuth( auth:IAuthHandler<Dynamic> ) {
				// Only check if tables already exist, otherwise, they're allowed in
				if (sys.db.TableCreate.exists(User.manager)) {
					var permissionID = Permission.getPermissionID( UFAdminPermissions.CanAccessAdminArea );
					var permissions = Permission.manager.search( $permission == permissionID);

					// If a group has this permission, and at least one member belongs to such a group.
					if (permissions.length>0 && permissions.exists(function (p) { return p.group.users.length > 0; })) {
						auth.requirePermission(UFAdminPermissions.CanAccessAdminArea);
					}
				}
				else {
					// assume Auth tables etc aren't set up yet and let them in without checking.
				}
			}

			function checkTablesExists() {
				if (!sys.db.TableCreate.exists(AdminTaskLog.manager)) sys.db.TableCreate.create(AdminTaskLog.manager);
			}

			function getLayout() {
				var layout = new UFAdminLayout();

				var links = [];
				for ( name in modules.keys() ) {
					links.push( { name: name, title: modules.get(name).title } );
				}
				links.cleverSort( _.title );
				layout.links = links;

				layout.title = "Ufront Admin Console";
				"".doesThisWork();
				layout.addStylesheet("/css/screen.css");

				// var server = context.request.clientHeaders.get("Host");
				var server = neko.Web.getClientHeader("Host");
				layout.head.append('<base href="http://$server$prefix/" />'.parse());
				return layout;
			}
		#end
	}
#end