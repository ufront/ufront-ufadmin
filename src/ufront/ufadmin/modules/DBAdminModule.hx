package ufront.ufadmin.modules;

import ufront.ufadmin.UFAdminModule;

class DBAdminModule extends UFAdminModule {
	public function new() {
		super( "db", "Database Admin" );
	}

	override public function checkPermissions() {
		// Currently anyone who has access to ufadmin has access to this DBAdminModule.
		return true;
	}

	@:route("/*")
	public function doDefault() {
		#if server
			if ( sys.db.Manager.cnx==null ) {
				return 'No Database Connection Found';
			}
			else {
				var base = context.generateUri( baseUri.substr(1) );
				spadm.AdminStyle.BASE_URL = base;
				ufront.spadm.DBAdmin.handler(base);
				context.completion.set( CRequestHandlersComplete );
				context.completion.set( CFlushComplete );
				return null;
			}
		#elseif
			return 'DBAdminModule is not available on the client';
		#end
	}
}
