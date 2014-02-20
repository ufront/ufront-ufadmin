package ufront.ufadmin.controller;


import ufront.web.context.ActionContext;
import ufront.web.Controller;
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

		@inject public var easyAuth:EasyAuth;

		var modules:StringMap<UFAdminModuleController>;
		var prefix:String;

		public function new( c:ActionContext ) {
			super( c );
			modules = new StringMap();

			// Figure out the prefix, needed for some absolute links
			var uri = c.request.uri;
			if ( uri.startsWith("/") ) uri = uri.substr( 1 );
			if ( uri.endsWith("/") ) uri = uri.substr( 0, uri.length-1 );
			var remainingUri = c.uriParts.join("/");

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
		public function loginScreen() {
			return drawLoginScreen( "" );
		}

		@:route( "/login/", POST )
		public function attemptLogin( args:{ user:String, pass:String } ) {
			return easyAuth
				.startSession( new EasyAuthDBAdapter(args.user,args.pass) )
				.map( function(outcome):ActionResult {
					switch outcome {
						case Success( u ):
							if ( passesAuth() ) 
								return new RedirectResult( prefix+"/" );
							else 
								// They're logged in, but don't have permission to be here.
								return throw DoesNotHavePermission('You do not have permission to access the $prefix/ folder');
						case Failure( e ):
							// They were not able to log in.
							return drawLoginScreen( args.user );
					}
				});
		}

		@:route( "/logout/" )
		public function doLogout() {
			easyAuth.endSession();
			return loginScreen();
		}

		@:route("/") 
		public function index():ActionResult {
			checkTablesExists();
			if ( passesAuth() ) {
				var view = new AdminView();
				var viewCont = getViewContainer();
				viewCont.contentContainer.append( view );
				return getLayout( "UF Admin Console", viewCont.html() );
			}
			else {
				if (context.auth.isLoggedIn()) return throw DoesNotHavePermission('You do not have permission to access the $prefix/ folder');
				else return loginScreen();
			}
		}

		@:route( "/$module/*" )
		public function doModule( module:String ) {

			if ( passesAuth() ) {
				if ( modules.exists(module) ) {
					var controller = modules.get(module);
					return controller.execute();
				}
				else return throw HttpError.pageNotFound();
			}
			else return throw DoesNotHavePermission('You do not have permission to access the /ufadmin/ folder');
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
				if (sys.db.TableCreate.exists(User.manager)) {
					var permissionID = Permission.getPermissionID( UFAdminPermissions.UFACanAccessAdminArea );
					var permissions = Permission.manager.search( $permission == permissionID);

					// If a group has this permission, and at least one member belongs to such a group.
					if (permissions.length>0 && permissions.exists(function (p) { return p.group.users.length > 0; })) {
						return context.auth.hasPermission(UFAdminPermissions.UFACanAccessAdminArea);
					}
				}
			}
			catch ( e:Dynamic ) {}
			
			// Either Auth tables aren't set up yet, or no one has "UFACanAccessAdminArea", so let them in.
			return true;
		}

		function drawLoginScreen( existingUser:String ) {
			var loginView = CompileTime.interpolateFile( "ufront/ufadmin/view/login.html" );
			return getLayout( "UF Admin Login", loginView );
		}

		function getLayout( title:String, content:String ) {
			var server = context.request.clientHeaders.get("Host");
			var content = CompileTime.interpolateFile( "ufront/ufadmin/view/layout.html" );
			return new ContentResult( content, "text/html" );
		}

		function getViewContainer() {
			var layout = new UFAdminLayout();

			var links:Array<{ slug:String, title:String }> = [];
			for ( module in modules ) {
				links.push( module );
			}
			links.cleverSort( _.title );
			layout.links = links;
			
			return layout;
		}
	}
#end