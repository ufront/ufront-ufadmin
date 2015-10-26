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
import minject.Injector;
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
	class UFAdminHomeController extends Controller {
		//
		// Member variables / methods
		//

		@inject public var easyAuthApi:EasyAuthApi;

		var modules:StringMap<UFAdminModule>;

		/**
		Add a set of modules to the controller.

		This should be run as part of dependency injection.
		**/
		@inject("", "adminModules")
		public function addModules( injector:Injector, moduleList:List<Class<UFAdminModule>> ) {
			modules = new StringMap();
			for ( module in moduleList ) {
				var controller = injector.instantiate( module );
				modules.set( controller.slug, controller );
			}
		}

		//
		// Key Routes
		//

		@:route( "/login/", GET )
		public function loginScreen():ActionResult {
			return drawLoginScreen( "" );
		}

		@:route( "/login/", POST )
		public function attemptLogin( args:{ user:String, pass:String } ):Future<ActionResult> {
			return easyAuthApi.attemptLogin( args.user, args.pass ).map(function(outcome):ActionResult {
				switch outcome {
					case Success( u ):
						if ( passesAuth() )
							return new RedirectResult( baseUri );
						else
							// They're logged in, but don't have permission to be here.
							throw HttpError.authError( ANoPermission(UFAdminPermissions.UFACanAccessAdminArea) );
					case Failure( e ):
						// They were not able to log in.
						return drawLoginScreen(args.user);
				}
			});
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
				links.sort( function(l1,l2) return Reflect.compare(l1.title,l2.title) );

				var template = CompileTime.readFile( "ufront/ufadmin/view/container.html" );
				return UFAdminModule.wrapInLayout( "Ufront Admin Console", template, { links:links } );
			}
			else {
				if (context.auth.isLoggedIn()) return throw HttpError.authError( ANoPermission(UFAdminPermissions.UFACanAccessAdminArea) );
				else return loginScreen();
			}
		}

		@:route( "/welcome/" )
		public function welcomePage() {
			if ( passesAuth() ) {
				var template = CompileTime.readFile( "ufront/ufadmin/view/welcome.html" );
				return UFAdminModule.wrapInLayout( "Ufront Admin Console", template, {} );
			}
			else return throw HttpError.authError( ANoPermission(UFAdminPermissions.UFACanAccessAdminArea) );
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
			else return throw HttpError.authError( ANoPermission(UFAdminPermissions.UFACanAccessAdminArea) );
		}

		//
		// Private
		//

		function checkTablesExists() {
			// if (!sys.db.TableCreate.exists(AdminTaskLog.manager)) sys.db.TableCreate.create(AdminTaskLog.manager);
		}

		function passesAuth():Bool {
			return context.auth.hasPermission( UFAdminPermissions.UFACanAccessAdminArea );
		}

		function drawLoginScreen( existingUser:String ) {
			return new ViewResult({
				existingUser: existingUser,
			}).usingTemplateString(
				CompileTime.readFile( "/ufront/ufadmin/view/login.html" ),
				CompileTime.readFile( "/ufront/ufadmin/view/layout.html" )
			);
		}
	}
#end
