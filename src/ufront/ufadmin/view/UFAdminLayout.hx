package ufront.ufadmin.view;

using Detox;

class UFAdminLayout extends dtx.widget.Widget
{
	public var links:Array<Link>;
}

typedef Link = { slug:String, title:String };