/**
 * @fileOverview The "widgets" plugin.
 *
 */

'use strict';

( function( $ ) {
	var widgetsReplaceRegex = /{{widget:([a-z\$_][a-z0-9\$_]*):(.*?):widget}}/gi;

	CKEDITOR.plugins.add( 'widgets', {
		requires: 'iframedialog',
		lang: 'en',
		icons: 'widgets',

		onLoad: function() {
			CKEDITOR.addCss( '.widget-placeholder {background:#eee;padding:6px 10px;border:1px solid #ccc;border-radius:5px;margin:2px;display:inline-block;}' );
			CKEDITOR.addCss( '.widget-placeholder .widget-title {background:#eee url(' + this.path + 'icons/widgets.png) 0px 3px no-repeat;padding-left: 20px;}' );
			CKEDITOR.addCss( '.widget-placeholder .config-summary { color:#888; font-style:italic; }' );
			CKEDITOR.addCss( '.widget-placeholder .widget-editable-content { display:none; background:#fff; padding : 10px; border:1px solid #ccc;border-radius:5px;margin-top:5px;min-height:3em; }' );
			CKEDITOR.addCss( '.widget-placeholder.with-editable-content { display : block; }' );
			CKEDITOR.addCss( '.widget-placeholder.with-editable-content > .widget-editable-content { display : block; }' );
		},

		init: function( editor ) {
			var lang = editor.lang.widgets;

			CKEDITOR.dialog.add( 'widgets', this.path + 'dialogs/widgets.js' );

			editor.ui.addButton && editor.ui.addButton( 'Widgets', {
				label: lang.toolbar,
				command: 'widgets',
				toolbar: 'insert,5',
				icon: 'widgets'
			} );

			editor.widgets.add( 'widgets', {
				  dialog   : 'widgets'
				, pathName : 'widgets'
				, template : '<div class="widget-placeholder"><div class="widget-title">&nbsp;</div><div class="widget-editable-content"><p></p></div></div>'
				, editables: {
			        content: {
			            selector: '.widget-editable-content'
			        }
				  }
				, init: function() {
					this.setData( 'raw', this.element.getAttribute( 'data-raw' ) );
				  }
				, downcast: function() {
					var widget = this
					  , element   = widget.element
					  , contentEl = element.find( ".widget-editable-content" ).getItem(0)
					  , config;

					if ( element.hasClass( "with-editable-content" ) ) {
						try {
							config = $.parseJSON( decodeURIComponent( widget.data.configJson ) );
						} catch(e){
							config = {};
						}
						config._inlineBody = encodeURIComponent( contentEl.getHtml() );
						widget.data.configJson = encodeURIComponent( JSON.stringify( config ) );
						widget.data.raw = "{{widget:" + widget.data.widgetId + ":" + widget.data.configJson + ":widget}}";
					}

					return new CKEDITOR.htmlParser.text( widget.data.raw );
				  }
				, data : function(){
					var widget = this
					  , element   = widget.element
					  , titleEl   = element.find( ".widget-title" ).getItem(0)
					  , contentEl = element.find( ".widget-editable-content" ).getItem(0)
					  , config, inlineBody = null;

					if ( widget.data.raw !== null && ( !widget._previousRaw || widget._previousRaw !== widget.data.raw ) ) {
						widget._previousRaw    = widget.data.raw;

						widget.data.widgetId   = widget.data.raw.replace( widgetsReplaceRegex, "$1");
						widget.data.configJson = widget.data.raw.replace( widgetsReplaceRegex, "$2");
						try {
							config = $.parseJSON( decodeURIComponent( widget.data.configJson ) );
							inlineBody = typeof config._inlineBody === "undefined" ? null : config._inlineBody;
						} catch(e){}


						titleEl.setText( i18n.translateResource( "widgets." + widget.data.widgetId + ":title", { defaultValue : widget.data.widgetId } ) );
						widget.element.addClass( "loading" );
						widget.element.setAttribute( "data-raw", widget.data.raw );

						if ( inlineBody !== null ) {
							widget.element.addClass( "with-editable-content" );
							contentEl.setHtml( decodeURIComponent( inlineBody ) );
						}

						$.ajax({
							  url     : buildAjaxLink( "widgets.renderWidgetPlaceholder" )
							, method  : "POST"
							, data    : { widgetId: widget.data.widgetId, data : widget.data.configJson }
							, success : function( data ) {
								widget.element.removeClass( "loading" );
								titleEl.setHtml( data );
							  }
							, error : function(){
								widget.element.removeClass( "loading" );
								widget.element.addClass( "error" );
							}
						});
					}
				}
			} );

			editor.setKeystroke( CKEDITOR.ALT + 87 /* W */, 'widgets' );
		},

		afterInit: function( editor ) {
			editor.dataProcessor.dataFilter.addRules( {
				text: function( text ) {
					return text.replace( widgetsReplaceRegex, function( match ) {
						var widgetWrapper = null
						  , innerElement  = new CKEDITOR.htmlParser.element( 'div', {
								  'class'    : 'widget-placeholder'
								, 'data-raw' : match
							} )
						  , title = new CKEDITOR.htmlParser.element( 'div', {
								  'class'    : 'widget-title'
							} )
						  , content = new CKEDITOR.htmlParser.element( 'div', {
								  'class'    : 'widget-editable-content'
							} );

						innerElement.add( title );
						innerElement.add( content );

						widgetWrapper = editor.widgets.wrapElement( innerElement, 'widgets' );

						return widgetWrapper.getOuterHtml();
					} );
				}
			} );
		}
	} );

} )( presideJQuery );