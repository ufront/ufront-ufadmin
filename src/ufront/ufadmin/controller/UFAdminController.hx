package ufront.ufadmin.controller;
import ufront.tasks.AdminTaskLog;
import ufront.web.mvc.Controller;
import ufront.web.mvc.ContentResult;
import ufront.web.mvc.DetoxResult;
import ufront.web.routing.RouteCollection;

import ufront.ufadmin.view.AdminView;
import ufront.ufadmin.view.TaskView;

import ufront.auth.model.User;
import ufront.auth.model.Permission;
import ufront.auth.UserAuth;

import dtx.DetoxLayout;

using Detox;
using Lambda;

class UFAdminController extends Controller
{
    public static var models:List<Class<Dynamic>> = new List();

    static var prefix = "/ufadmin";

    static public function addRoutes(routes:RouteCollection, ?p:String = "/admin")
    {
        if (p != null) prefix = p;
        routes
        .addRoute(prefix + "/", { controller : "UFAdminController", action : "index" } )
        .addRoute(prefix + "/tasks/", { controller : "UFTaskController", action : "viewTasks" } )
        .addRoute(prefix + "/tasks/run/", { controller : "UFTaskController", action : "run" } )
        .addRoute(prefix + "/db", { controller : "SpodAdminController", action : "runSpodAdmin" } )
        .addRoute(prefix + "/db/{?*rest}", { controller : "SpodAdminController", action : "runSpodAdmin" } )
        .addRoute(prefix + "/{?*rest}", { controller : "UFAdminController", action : "notFound" } )
        ;
    }

    public function index() 
    {
        checkAuth();
        checkTablesExists();
        var view = new AdminView();
        return new DetoxResult(view, getLayout());
    }

    public function notFound() 
    {
        checkAuth();
        var view = "Page not found.".parse();
        return new DetoxResult(view, getLayout());
    }

    function checkTablesExists()
    {
        if (!sys.db.TableCreate.exists(AdminTaskLog.manager)) sys.db.TableCreate.create(AdminTaskLog.manager);
    }

    public static function getLayout()
    {
        var template = CompileTime.readXmlFile("ufront/ufadmin/view/layout.html");
        var layout = new DetoxLayout(template);
        layout.title = "Ufront Admin Console";
        layout.addStylesheet("/css/screen.css");

        var server = neko.Web.getClientHeader("Host");
        layout.head.append('<base href="http://$server$prefix/" />'.parse());
        return layout;
    }

    public static function checkAuth()
    {
        // Only check if tables already exist, otherwise, they're allowed in
        if (sys.db.TableCreate.exists(User.manager))
        {
            var permissionID = Permission.getPermissionID(UFAdminPermissions.CanAccessAdminArea);
            var permissions = Permission.manager.search($permission == permissionID);

            // If a group has this permission, and at least one member belongs to such a group.
            if (permissions.length > 0 && permissions.exists(function (p) { return p.group.users.length > 0; }))
            {
                UserAuth.requirePermission(UFAdminPermissions.CanAccessAdminArea);
            }
            // Else: assume stuff isn't set up yet and let them in without checking.
        }

    }
}