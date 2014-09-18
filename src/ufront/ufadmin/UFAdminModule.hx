package ufront.ufadmin;

import ufront.web.Controller;
import ufront.web.result.ViewResult;
import ufront.view.TemplateData;

/**
	A base-class used to define a controller that can be used in the UFAdmin control panel.

	It adds "slug", "title" and "checkPermissions" so that menus appropriate for the current user can be constructed.
**/
class UFAdminModule extends Controller {
	
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
	function thisIsAWorkaround():Void {
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
	
	/**
		A helper function for UFAdmin modules to wrap their content in a layout.
		The layout has a simple HTML structure, the bootstrap stylesheet, and a base HREF relative the `/ufadmin/` path.

		@param title The title of the current page.
		@param template The string of the template to use. We recommend including this using `CompileTime.readFile(view.html)` or similar to avoid runtime dependencies.
		@param data The `TemplateData` to use when rendering the template.
		@return ViewResult A ready to use ViewResult.
	**/
	public static function wrapInLayout( title:String, template:String, data:TemplateData ):ViewResult {
		return new ViewResult( data )
			.setVar( "title", title )
			.usingTemplateString(
				template,
				CompileTime.readFile( "/ufront/ufadmin/view/layout.html" )
			);
	}
}