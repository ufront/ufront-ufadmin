package ufront.ufadmin.controller;

import ufront.web.Controller;

/**
	A typedef used to define a controller that can be used in the UFAdmin control panel.

	It is similar to IndexController, allowing the module controller to be constructed and executed reliably.

	It adds "slug", "title" and "checkPermissions" so that menus appropriate for the current user can be constructed.
**/
class UFAdminModuleController extends Controller {
	
	/** The url slug for this controller.  Should be URL-friendly (a-zA-Z0-9_-) **/
	public var slug:String;

	/** The title of this module, to show in side menus etc **/
	public var title:String;

	function new( slug:String, title:String ) {
		super();
		this.slug = slug;
		this.title = title;
	}

	@:route( "this-is-a-workaround" )
	function workaround() {
		// Currently there is no way to skip checking for @:route metadata in the build macro.
		// Until I set that up, this route / method exists solely to silence the error message.
		// Don't hate me!
	}
	
	/**
		Check if the current auth session has permission to use this module.
		
		Use `context.auth.checkPermission()` etc to check.

		If this does not return true, the module will not be added to menu, and the user will not be able to access this module.

		By default this simply returns true.
	**/
	public function checkPermissions():Bool {
		return true;
	}
}