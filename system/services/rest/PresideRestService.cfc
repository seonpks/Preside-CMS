/**
 * An object to provide the PresideCMS REST platform's
 * business logic.
 *
 * @autodoc true
 * @singleton
 *
 */
component {

	/**
	 * @resourceDirectories.inject presidecms:directories:handlers/rest-apis
	 * @controller.inject          coldbox
	 *
	 */
	public any function init( required array resourceDirectories, required any controller ) {
		_setApis( new PresideRestResourceReader().readResourceDirectories( arguments.resourceDirectories ) );
		_setController( arguments.controller );

		return this;
	}

	public void function onRestRequest( required string uri, required any requestContext ) {
		var response = createRestResponse();
		var verb     = arguments.requestContext.getHttpMethod();

		_announceInterception( "onRestRequest", { uri=uri, verb=verb, response=response } );

		if ( !response.isFinished() ) {
			processRequest(
				  uri            = arguments.uri
				, verb           = verb
				, requestContext = arguments.requestContext
				, response       = response
			);
		}

		processResponse(
			  response       = response
			, requestContext = arguments.requestContext
		);
	}

	public void function processRequest( required string uri, required string verb, required any requestContext, required any response ) {
		var resource = getResourceForUri( arguments.uri );

		if ( !resource.count() ) {
			response.setError(
				  errorCode = 404
				, type      = "REST API Resource not found"
				, message   = "The requested resource, [#arguments.uri#], did not match any resources in the Preside REST API"
			);

			_announceInterception( "onMissingRestResource", { uri=uri, verb=verb, response=response } );
			return;
		}

		if ( !resource.verbs.keyExists( verb ) ) {
			response.setError(
				  errorCode = 405
				, type      = "REST API Method not supported"
				, message   = "The requested resource, [#arguments.uri#], does not support the [#UCase( verb )#] method"
			);

			_announceInterception( "onUnsupportedRestMethod", { uri=uri, verb=verb, response=response } );
			return;
		}

		invokeRestResourceHandler(
			  resource       = resource
			, uri            = uri
			, verb           = verb
			, response       = response
			, requestContext = requestContext
		);
	}

	public void function invokeRestResourceHandler(
		  required struct resource
		, required string uri
		, required string verb
		, required any    response
		, required any    requestContext
	) {
		var args = extractTokensFromUri(
			  uriPattern = arguments.resource.uriPattern
			, tokens     = arguments.resource.tokens
			, uri        = arguments.uri
		);

		args.response = arguments.response;

		_announceInterception( "preInvokeRestResource", { uri=arguments.uri, verb=arguments.verb, response=arguments.response, args=args } );
		if ( arguments.response.isFinished() ) {
			return;
		}

		_getController().runEvent(
			  event          = "rest-apis.#arguments.resource.handler#.#arguments.resource.verbs[ arguments.verb ]#"
			, prePostExempt  = false
			, private        = true
			, eventArguments = args
		);

		_announceInterception( "postInvokeRestResource", { uri=arguments.uri, verb=arguments.verb, response=arguments.response, args=args } );
	}

	public void function processResponse( required any response, required any requestContext ) {
		var headers = response.getHeaders() ?: {};

		for( var headerName in headers ) {
			requestContext.setHttpHeader( name=headerName, value=headers[ headerName ] );
		}

		requestContext.renderData(
			  type        = response.getRenderer()
			, data        = response.getData() ?: ""
			, contentType = response.getMimeType()
			, statusCode  = response.getStatusCode()
			, statusText  = response.getStatusText()
		);
	}

	public struct function getResourceForUri( required string restPath ) {
		var apiPath      = getApiForUri( arguments.restPath );
		var apis         = _getApis();
		var apiResources = apis[ apiPath ] ?: [];
		var resourcePath = arguments.restPath.replace( apiPath, "" );

		for( var resource in apiResources ) {
			if ( ReFindNoCase( resource.uriPattern, resourcePath ) ) {
				return resource;
			}
		}

		return {};
	}

	public string function getApiForUri( required string restPath ) {
		for( var apiPath in _getApiList() ) {
			if ( arguments.restPath.startsWith( apiPath ) ) {
				return apiPath;
			}
		}

		return "";
	}

	public struct function extractTokensFromUri(
		  required string uriPattern
		, required array  tokens
		, required string uri
	) {
		var findResult = ReFindNoCase( arguments.uriPattern, arguments.uri, 0, true );
		var extracted  = {};

		for( var i=1; i<=arguments.tokens.len(); i++ ) {
			if ( findResult.pos[i+1] ?: 0 ) {
				extracted[ arguments.tokens[ i ] ] = Mid( arguments.uri, findResult.pos[i+1], findResult.len[i+1] );
			}
		}

		return extracted;
	}

	public any function createRestResponse() {
		return new PresideRestResponse();
	}

// PRIVATE HELPERS
	private array function _getApiList() {
		if ( !variables.keyExists( "_apiList" ) ) {
			_apiList = _getApis().keyArray();
			_apiList.sort( function( a, b ){
				return a.len() > b.len() ? -1 : 1;
			} );
		}

		return _apiList;
	}

	private void function _announceInterception( required string state, struct interceptData={} ) {
		_getInterceptorService().processState( argumentCollection=arguments );
	}

	private any function _getInterceptorService() {
		return _getController().getInterceptorService();
	}

// GETTERS AND SETTERS
	private struct function _getApis() {
		return _apis;
	}
	private void function _setApis( required struct apis ) {
		_apis = arguments.apis;
	}


	private any function _getController() {
		return _controller;
	}
	private void function _setController( required any controller ) {
		_controller = arguments.controller;
	}

}