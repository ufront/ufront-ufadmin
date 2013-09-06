package ufront.ufadmin.controller;

import ufront.web.Controller;
import ufront.web.result.*;
import ufront.ufadmin.view.TaskView;
import ufront.tasks.AdminTaskSet;
import dtx.DetoxLayout;
import haxe.CallStack;
using Detox;
using Lambda;
using ufront.util.TimeOfDayTools;
using StringTools;

class UFTaskController extends ufront.web.Controller
{
    public function doDefault() {
        UFAdminController.checkAuth();
        var view = new TaskView();
        view.taskSets.addList( AdminTaskSet.allTaskSets );
        return new DetoxResult(view, UFAdminController.getLayout());
    }

    public function doRun()
    {
        UFAdminController.checkAuth();
        try 
        {
            var post = this.controllerContext.request.post;
            if (post.exists("taskSet"))
            {
                var tsName = post.get("taskSet");
                
                if (post.exists("runAll"))
                {
                    return runTaskSet(tsName);
                }
                else if (post.exists("task"))
                {
                    var taskName = post.get("task");
                    return runSingleTask(tsName, taskName);
                }
                else throw "Both taskSet and task must be given as POST parameters";
            }
            else throw "taskSet must be given as a GET parameter";
        }
        catch (e:Dynamic)
        {
            var err = Std.string(e).htmlEscape();
            var exceptionStack = CallStack.toString(CallStack.exceptionStack());
            var output = '<h1>Error:</h1>
            <h4>$err</h4>
            <h5>Exception Stack:</h5>
            <pre>$exceptionStack</pre>';
            return new DetoxResult(output.parse(), UFAdminController.getLayout());
        }
    }

    function runTaskSet(tsName:String)
    {
        var ts = getTaskSet(tsName);

        var view = new TaskResultView();
        view.taskSet = ts.taskSetTitle;
        view.taskSetDescription = ts.taskSetDescription;
        
        for (task in ts.tasks)
        {
            var result = runTask(tsName, task.name, this.controllerContext.request.post);
            view.results.addItem({
                task: task.title,
                description: (task.description == "") ? "..." : task.description,
                output: result.result.output,
                timeTaken: result.timeTaken
            });
        }

        return new DetoxResult(view, UFAdminController.getLayout());
    }

    function runSingleTask(tsName:String, taskName:String)
    {
        var result = runTask(tsName, taskName, this.controllerContext.request.post);

        var view = new TaskResultView();

        view.taskSet = result.ts.taskSetTitle;
        view.taskSetDescription = result.ts.taskSetDescription;
        view.results.addItem({
            task: result.task.title,
            description: (result.task.description == "") ? "..." : result.task.description,
            output: result.result.output,
            timeTaken: result.timeTaken
        });

        return new DetoxResult(view, UFAdminController.getLayout());
    }

    public function runTask(tsName:String, taskName:String, inputs:Map<String,String>)
    {
        var ts = getTaskSet(tsName);
        
        // Get TaskSet inputs
        for (inputName in ts.taskSetInputs)
        {
            if (inputs.exists("ts_" + inputName))
            {
                var varValue = inputs.get("ts_" + inputName);
                if (varValue == "") throw 'The TaskSet input $inputName was empty';
                Reflect.setProperty(ts, inputName, varValue);
            }
            else throw 'The TaskSet input $inputName was missing';
        }

        // Get Task inputs
        var currentTask = ts.tasks.filter(function (t) { return t.name == taskName; })[0];
        var taskInputs = [];
        if (currentTask != null)
        {
            for (inputName in currentTask.inputs)
            {
                var postName = 'task_${taskName}_${inputName}';
                if (inputs.exists(postName))
                {
                    var varValue = inputs.get(postName);
                    if (varValue == "") 
                        throw 'The Task input $inputName was empty';
                    else 
                        taskInputs.push(varValue);
                    
                }
                else throw 'The Task input $inputName was missing';
            }
        }

        // Execute the task
        var startTime = Date.now().getTime();
        var result = ts.run(taskName, taskInputs);
        var timeTaken = Std.int((Date.now().getTime() - startTime) / 1000);
        var timeTakenStr = timeTaken.timeToString();

        return {
            ts: ts,
            task: currentTask,
            result: result,
            timeTaken: timeTakenStr
        };
    }

    var ts:AdminTaskSet;
    function getTaskSet(tsName:String)
    {
        if (ts == null)
        {
            var tsClass = Type.resolveClass(tsName);
            if (tsClass == null) throw "The TaskSet you asked for was not found: " + tsName;
            ts = untyped Type.createInstance(tsClass, []);
        }
        return ts;
    }
}