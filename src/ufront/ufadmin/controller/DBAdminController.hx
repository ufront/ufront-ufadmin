package ufront.ufadmin.controller;
import ufront.web.Controller;
import ufront.web.Dispatch;

class DBAdminController extends Controller
{
	public function doDefault( d:Dispatch )
	{
		#if neko 
			spadm.AdminStyle.BASE_URL = "/ufadmin/db/";
			ufront.spadm.DBAdmin.handler("/ufadmin/db/");
			context.httpContext.completion.set( CRequestHandlersComplete );
			context.httpContext.completion.set( CFlushComplete );
		#else 
			throw "I'm sorry, SPOD Admin only runs on Neko currently... we'll have to look into this!";
		#end

		return "";
	}
}