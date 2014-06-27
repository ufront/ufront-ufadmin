package ufront.ufadmin.controller;


import ufront.web.context.HttpContext;
import ufront.web.Controller;
import ufront.web.result.ActionResult;
import ufront.web.result.*;
import ufront.auth.model.*;
import ufront.auth.*;
import ufront.auth.AuthError;
import ufront.web.HttpError;
import haxe.ds.StringMap;
import ufront.auth.api.EasyAuthApi;
import tink.CoreApi;
using thx.util.CleverSort;
using Lambda;
using StringTools;

#if server
	/**
		A simple admin area for your site.  

		Default modules include:

		- DBAdminModule

		More can be added using `addModule()`
	**/
	class UFAdminController extends Controller
	{
		//
		// Member variables / methods
		//

		@inject public var easyAuthApi:EasyAuthApi;

		var modules:StringMap<UFAdminModuleController>;
		var prefix:String;

		public function new( c:HttpContext ) {
			super( c );
			modules = new StringMap();

			// Figure out the prefix, needed for some absolute links
			var uri = c.request.uri;
			if ( uri.startsWith("/") ) uri = uri.substr( 1 );
			if ( uri.endsWith("/") ) uri = uri.substr( 0, uri.length-1 );
			var remainingUri = c.actionContext.uriParts.join("/");

			var prefixLength = uri.length-remainingUri.length;
			prefix = "/"+uri.substr( 0, prefixLength );
			if ( prefix.endsWith("/") ) prefix = prefix.substr( 0, prefix.length-1 );

			// Add default modules
			addModule( DBAdminModule );
		}

		/**
			Add a controller to the UFAdminController menu

			Any controller added will be available as a subroute of your admin area.  eg `/ufadmin/db/`

			The module will only be accessible if the user has the `UFAdminPermissions.CanAccessAdminArea` permission and if the module's `checkPermissions()` function returns true.

			Modules will be sorted alphabetically by their `slug` field.

			@param name: the slug/URL to use for this module
			@param title: the name to give this module on the side menu
			@param controller: the instantiated module
		**/
		public function addModule( controllerClass:Class<UFAdminModuleController> ) {
			var controller = Type.createInstance( controllerClass, [this.context] );
			modules.set( controller.slug, controller );
		}

		/**
			Clear the existing modules, including those added by default.
		**/
		public function clearModules() {
			modules = new StringMap();
		}

		//
		// Key Routes
		// 

		@:route( "/login/", GET )
		public function loginScreen():ActionResult {
			return drawLoginScreen( "" );
		}

		@:route( "/login/", POST )
		public function attemptLogin( args:{ user:String, pass:String } ):ActionResult {
			switch easyAuthApi.attemptLogin( args.user, args.pass ) {
				case Success( u ):
					if ( passesAuth() ) 
						return new RedirectResult(prefix+"/");
					else 
						// They're logged in, but don't have permission to be here.
						throw NoPermission(UFAdminPermissions.UFACanAccessAdminArea);
				case Failure( e ):
					// They were not able to log in.
					return drawLoginScreen(args.user);
			}
		}

		@:route( "/logout/" )
		public function doLogout():ActionResult {
			easyAuthApi.logout();
			return loginScreen();
		}

		@:route("/") 
		public function index():ActionResult {
			checkTablesExists();
			if ( passesAuth() ) {
				var view = CompileTime.interpolateFile( "ufront/ufadmin/view/welcome.html" );
				return wrapInLayout( "UF Admin Console", wrapInContainer(view) );
			}
			else {
				if (context.auth.isLoggedIn()) return throw NoPermission(UFAdminPermissions.UFACanAccessAdminArea);
				else return loginScreen();
			}
		}

		@:route( "/$module/*" )
		public function doModule( module:String ):FutureActionOutcome {

			if ( passesAuth() ) {
				if ( modules.exists(module) ) {
					var controller = modules.get(module);
					return controller.execute();
				}
				else return throw HttpError.pageNotFound();
			}
			else return throw NoPermission(UFAdminPermissions.UFACanAccessAdminArea);
		}

		//
		// Private
		// 

		function checkTablesExists() {
			// if (!sys.db.TableCreate.exists(AdminTaskLog.manager)) sys.db.TableCreate.create(AdminTaskLog.manager);
		}

		function passesAuth():Bool {
			// Only check if tables already exist, otherwise, they're allowed in
			try {
				if (sys.db.TableCreate.exists(Permission.manager)) {
					var permissionID = Permission.getPermissionID( UFAdminPermissions.UFACanAccessAdminArea );
					var permissions = Permission.manager.search($permission == permissionID);

					// If a group has this permission, and at least one member belongs to such a group.
					if (permissions.length>0 && permissions.exists(function (p) { return p.user!=null || (p.group!=null && p.group.users.length>0); })) {
						return context.auth.hasPermission(UFAdminPermissions.UFACanAccessAdminArea);
					}
				}
			}
			catch ( e:Dynamic ) {
				ufError('Failed to check for permissions: $e');
			}
			
			// Either Auth tables aren't set up yet, or no one has "UFACanAccessAdminArea", so let them in.
			ufLog("/ufadmin/ is being accessed when the tables and permissions are not set up, so we are not checking authentication.");
			return true;
		}

		function drawLoginScreen( existingUser:String ) {
			var loginView = CompileTime.interpolateFile( "ufront/ufadmin/view/login.html" );
			return wrapInLayout( "UF Admin Login", loginView );
		}

		function wrapInLayout( title:String, content:String ) {
			var server = context.request.clientHeaders.get("Host");
			var content = CompileTime.interpolateFile( "ufront/ufadmin/view/layout.html" );
			return new ContentResult( content, "text/html" );
		}

		function wrapInContainer( view:String ) {
			// var layout = new UFAdminLayout();

			var links:Array<{ slug:String, title:String }> = [];

			for ( module in modules ) {
				links.push( module );
			}
			links.cleverSort( _.title );
			var moduleLinks = [ for (l in links) '<li><a href="./${l.slug}/">${l.title}</a></li>' ].join("\n");
			

			return CompileTime.interpolateFile( "ufront/ufadmin/view/container.html" );
		}
	}
#end