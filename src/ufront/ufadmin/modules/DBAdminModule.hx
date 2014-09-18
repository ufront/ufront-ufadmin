package ufront.ufadmin.modules;

import ufront.ufadmin.UFAdminModule;
import ufront.web.Dispatch;

class DBAdminModule extends UFAdminModule
{
	public function new() {
		super( "db", "Database Admin" );
	}

	public function checkPermissions() {
		return true; // Set up more fine grained permissions later...
	}

	@:route("/*")
	public function doDefault()
	{
		spadm.AdminStyle.BASE_URL = "/ufadmin/db/";
		ufront.spadm.DBAdmin.handler("/ufadmin/db/");
		context.completion.set( CRequestHandlersComplete );
		context.completion.set( CFlushComplete );
	}
}