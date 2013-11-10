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

	import ufront.auth.model.*;
	import ufront.auth.*;
	import ufront.auth.PermissionError;
	import ufront.web.HttpError;

	import dtx.layout.DetoxLayout;
	import haxe.ds.StringMap;
	import ufront.web.Dispatch;
	import haxe.web.Dispatch.DispatchConfig;
	import ufront.auth.*;
	import tink.CoreApi;
	using thx.util.CleverSort;
	using Detox;
	using Lambda;
#end

#if server
	/**
		A simple admin area for your site.  

		Does not include much by default, but you can add other controllers (modules) such as the DBAdminController or your own custom controller.
	**/
	class UFAdminController extends Controller
	{
		/**
			Add a controller to the UFAdminController menu

			Any controller added will be available as a subroute of your admin area, and will require the `UFAdminPermissions.CanAccessAdminArea` permission.  

			If no user has that permission, it is assumed your site is still not completely set up, and access will be granted.

			@param name: the slug/URL to use for this module
			@param title: the name to give this module on the side menu
			@param controller: the instantiated module
		**/
		public static macro function addModule( name:ExprOf<String>, title:ExprOf<String>, controller:ExprOf<{}> ):ExprOf<haxe.web.Dispatch.DispatchConfig> {
			return macro UFAdminController.modules.set( $name, { title: $title, dispatch: ufront.web.Dispatch.make($controller) } );
		}

		#if !macro
			
			static var modules:StringMap<{ title:String, dispatch:DispatchConfig }> = new StringMap();
			public static var prefix = "/ufadmin";
			@inject public var easyAuth:EasyAuth;

			//
			// Dispatch actions
			// 

			public function doDefault( ?module:String, d:Dispatch ) {

				checkTablesExists();
				if ( passesAuth() ) {
					if ( module==null ) {
						var view = new AdminView();
						var viewCont = getViewContainer();
						viewCont.contentContainer.append( view );
						return getLayout( "UF Admin Console", viewCont.html() );
					}
					else {
						if ( modules.exists(module) ) 
							return d.runtimeReturnDispatch( modules.get(module).dispatch );
						else 
							return throw HttpError.pageNotFound();
					}
				}
				else {
					if (context.auth.isLoggedIn()) 
						return throw DoesNotHavePermission('You do not have permission to access the /ufadmin/ folder');
					else 
						return cast doLogin( d );
				}
			}

			public function doLogin( d:Dispatch, ?args:{ user:String, pass:String } ) {

				if (args==null) {
					return drawLoginScreen( "" );
				}
				else {
					// SYNC HACK: `auth.startSession` returns a Future, but I haven't set up sync APIs/Controllers at
					// the time of writing, and I'm only using this on Neko/PHP so far, so you can use this sync hack
					// to get away with it.  Shouldn't be hard to patch up later.
					var outcome:Outcome<User, PermissionError> = null;
					easyAuth
						.startSession( new EasyAuthDBAdapter(args.user,args.pass) )
						.handle( function(o) outcome=o );
					switch outcome {
						case Success( u ):
							if ( passesAuth() ) 
								return cast new RedirectResult( prefix+"/" );
							else 
								return drawLoginScreen( args.user );
						case Failure( e ):
							return drawLoginScreen( args.user );
					}
				}
			}

			public function doLogout( d:Dispatch ) {
				easyAuth.endSession();
				return doLogin( d );
			}

			//
			// Private
			// 

			function checkTablesExists() {
				if (!sys.db.TableCreate.exists(AdminTaskLog.manager)) sys.db.TableCreate.create(AdminTaskLog.manager);
			}

			function passesAuth():Bool {
				// Only check if tables already exist, otherwise, they're allowed in
				if (sys.db.TableCreate.exists(User.manager)) {
					var permissionID = Permission.getPermissionID( UFAdminPermissions.CanAccessAdminArea );
					var permissions = Permission.manager.search( $permission == permissionID);

					// If a group has this permission, and at least one member belongs to such a group.
					if (permissions.length>0 && permissions.exists(function (p) { return p.group.users.length > 0; })) {
						return context.auth.hasPermission(UFAdminPermissions.CanAccessAdminArea);
					}
				}
				// Either Auth tables aren't set up yet, or no one has "CanAccessAdminArea", so let them in.
				return true;
			}

			function drawLoginScreen( existingUser:String ) {
				var loginView = CompileTime.interpolateFile( "ufront/ufadmin/view/login.html" );
				return getLayout( "UF Admin Login", loginView );
			}

			function getLayout( title:String, content:String ) {
				var server = context.request.clientHeaders.get("Host");
				return CompileTime.interpolateFile( "ufront/ufadmin/view/layout.html" );
			}

			function getViewContainer() {
				var layout = new UFAdminLayout();

				var links = [];
				for ( name in modules.keys() ) {
					links.push( { name: name, title: modules.get(name).title } );
				}
				links.cleverSort( _.title );
				layout.links = links;
				
				return layout;
			}
		#end
	}
#end