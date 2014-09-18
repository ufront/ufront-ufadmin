package ufront.ufadmin.controller;


import ufront.web.context.HttpContext;
import ufront.web.Controller;
import ufront.web.result.ActionResult;
import ufront.web.result.*;
import ufront.auth.model.*;
import ufront.auth.*;
import ufront.auth.AuthError;
import ufront.web.HttpError;
import ufront.view.TemplateData;
import haxe.ds.StringMap;
import ufront.auth.api.EasyAuthApi;
import tink.CoreApi;
using CleverSort;
using haxe.io.Path;
using Lambda;
using StringTools;

#if server
	/**
		A simple admin area for your site.  

		Default modules include:

		- DBAdminModule

		More can be added using `addModule()`
	**/
	class UFAdminHomeController extends Controller
	{
		//
		// Member variables / methods
		//

		@inject public var easyAuthApi:EasyAuthApi;
		@inject("adminModules") public var moduleList:List<Class<UFAdminModule>>;
		
		var modules:StringMap<UFAdminModule> = new StringMap();
		
		@post public function postInjection() {
			
			// Add default modules
			for ( module in moduleList )
				addModule( module );
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
		public function addModule( controllerClass:Class<UFAdminModule> ) {
			var controller = context.injector.instantiate( controllerClass );
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
						return new RedirectResult( baseUri );
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
			
				var links:Array<{ slug:String, title:String }> = [];

				for ( module in modules ) 
					links.push( module );
				links.cleverSort( _.title );

				var template = CompileTime.readFile( "ufront/ufadmin/view/container.html" );
				return UFAdminModule.wrapInLayout( "Ufront Admin Console", template, { links:links } );
			}
			else {
				if (context.auth.isLoggedIn()) return throw NoPermission(UFAdminPermissions.UFACanAccessAdminArea);
				else return loginScreen();
			}
		}
		
		@:route( "/welcome/" )
		public function welcomePage() {
			if ( passesAuth() ) {
				var template = CompileTime.readFile( "ufront/ufadmin/view/welcome.html" );
				return UFAdminModule.wrapInLayout( "Ufront Admin Console", template, {} );
			}
			else return throw NoPermission(UFAdminPermissions.UFACanAccessAdminArea);
		}

		@:route( "/$module/*" )
		public function doModule( module:String ):FutureActionOutcome {

			if ( passesAuth() ) {
				if ( modules.exists(module) ) {
					var controller = modules.get( module );
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
			return new ViewResult({
				existingUser: existingUser,
				baseUri: baseUri,
			}).usingTemplateString(
				CompileTime.readFile( "/ufront/ufadmin/view/login.html" ),
				CompileTime.readFile( "/ufront/ufadmin/view/layout.html" )
			);
		}
	}
#end