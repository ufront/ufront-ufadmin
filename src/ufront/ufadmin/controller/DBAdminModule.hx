package ufront.ufadmin.controller;
import ufront.web.Controller;
import ufront.web.Dispatch;

class DBAdminModule extends Controller
{
	public var slug="db";
	public var title="Database";

	public function checkPermissions() {
		return true; // Set up more fine grained permissions later...
	}

	@:route("/*")
	public function doDefault()
	{
		spadm.AdminStyle.BASE_URL = "/ufadmin/db/";
		ufront.spadm.DBAdmin.handler("/ufadmin/db/");
		context.httpContext.completion.set( CRequestHandlersComplete );
		context.httpContext.completion.set( CFlushComplete );
	}
}