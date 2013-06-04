package ufront.controller.admin;
import ufront.web.mvc.Controller;
import ufront.web.mvc.ContentResult;
import ufront.web.mvc.DetoxResult;
import ufront.web.routing.RouteCollection;

import ufront.view.admin.AdminView;
import ufront.view.admin.*;
import ufront.db.Migration;

import dtx.DetoxLayout;

using Detox;
using Lambda;

class UFMigrationController extends Controller
{
    public function viewMigrations()
    {
        UFAdminController.checkAuth();
        return displayMigrationsAndResults();
    }

    function displayMigrationsAndResults(?results:Array<MigrationResults>)
    {
        var migrations = getMigrationGroups();
        var view = new MigrationView();

        if (results != null)
        {
            for (r in results) 
                view.addResults(r);
        }
        else 
        {
            view.results.addClass("hidden");
        }

        view.runUp.addList(migrations.up.map(function (m) { return m.name; } ));
        view.runDown.addList(migrations.down.map(function (m) { return m.name; } ));
        view.alreadyRun.addList(migrations.leave.map(function (m) { return m.name; } ));
        
        return new DetoxResult(view, UFAdminController.getLayout());
    }

    public function runMigrations() 
    {
        UFAdminController.checkAuth();
        var migrations = getMigrationGroups();

        var results:Array<MigrationResults> = [];
        for (m in migrations.down)
        {
            var r = m.run(Down);
            results.push(r);
        }
        for (m in migrations.up)
        {
            var r = m.run(Up);
            results.push(r);
        }

        // Now that we have run the migrations
        return displayMigrationsAndResults(results);
    }

    public function runMigrationUp() 
    {
        UFAdminController.checkAuth();
        try 
        {
            var postData = this.controllerContext.request.post;
            if (postData.exists('migration')) 
            {
                var migName = postData.get('migration');
                var migrationClass = Type.resolveClass(migName);
                if (migrationClass != null)
                {
                    var migration = Type.createInstance(migrationClass, []);
                    var results = migration.run(Up);
                    return displayMigrationsAndResults([results]);
                }
                else 
                {
                    throw "The specified migration file was not found";
                }
            }
            else 
            {
                throw "No migration was specified.";
            }
        }
        catch (e:String)
        {
            var view = e.parse();
            return new DetoxResult(view, UFAdminController.getLayout());
        }
    }

    public function runMigrationDown() 
    {
        UFAdminController.checkAuth();
        try 
        {
            var postData = this.controllerContext.request.post;
            trace (postData);
            if (postData.exists('migration')) 
            {
                var migName = postData.get('migration');
                var migration = Migration.manager.select($name == migName);
                if (migration != null)
                {
                    var results = migration.run(Down);
                    return displayMigrationsAndResults([results]);
                }
                else 
                {
                    throw "The specified migration was not already in the database, so you can't take it Down.";
                }
            }
            else 
            {
                throw "No migration was specified.";
            }
        }
        catch (e:String)
        {
            var view = e.parse();
            return new DetoxResult(view, UFAdminController.getLayout());
        }
    }

    function getMigrationGroups()
    {
        var migrationFilesList:List<Class<Migration>> = cast CompileTime.getAllClasses(Migration);
        var migrationFiles = migrationFilesList.map(function (c) { return Type.createInstance(c, []); });

        var migrationRows = Migration.manager.all();

        var up:Array<Migration> = [];
        var down:Array<Migration> = [];
        var leave:Array<Migration> = [];

        for (migOnDB in migrationRows)
        {
            if (migrationFiles.exists(function (m) return m.name == migOnDB.name))
            {
                // It is on the Database and in the files
                leave.push(migOnDB);
                // Remove from the list, so that at the end all that remains is those not in the DB
                for (m in migrationFiles) 
                {
                    if (m.name == migOnDB.name) migrationFiles.remove(m);
                }
            }
            else 
            {
                // It is on the DB, but not in the files
                down.push(migOnDB);
            }
        }

        // The leftovers are what are in files but not in the DB
        for (m in migrationFiles) up.push(m);

        var alphabeticalSort = function(a,b) return Reflect.compare(a.name.toLowerCase(),b.name.toLowerCase());
        up.sort(alphabeticalSort);
        down.sort(alphabeticalSort);
        leave.sort(alphabeticalSort);


        return {
            up: up,
            down: down,
            leave: leave
        }
    }
}