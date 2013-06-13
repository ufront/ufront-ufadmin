package ufront.ufadmin.controller;
import ufront.web.mvc.Controller;
import ufront.web.mvc.ContentResult;
import ufront.web.mvc.DetoxResult;
import ufront.web.routing.RouteCollection;


class SpodAdminController extends Controller
{
	public function runSpodAdmin()
	{
		UFAdminController.checkAuth();
		#if neko 
			spadm.AdminStyle.BASE_URL = "/ufadmin/db/";
			ufront.spadm.DBAdmin.handler("/ufadmin/db/");
		#else 
			throw "I'm sorry, SPOD Admin only runs on Neko currently... we'll have to look into this!";
		#end
	}
}