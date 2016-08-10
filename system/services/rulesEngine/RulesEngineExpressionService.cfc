/**
 * Service that provides logic for dealing with rule engine expressions.
 * See [[rules-engine]] for further details.
 *
 * @singleton
 * @presideservice
 * @autodoc
 */
component displayName="RulesEngine Expression Service" {


// CONSTRUCTOR
	/**
	 * @expressionReaderService.inject rulesEngineExpressionReaderService
	 * @expressionDirectories.inject   presidecms:directories:/handlers/rules/expressions
	 *
	 */
	public any function init( required any expressionReaderService, required array expressionDirectories ) {
		_setExpressions( expressionReaderService.getExpressionsFromDirectories( expressionDirectories ) )

		return this;
	}

// PUBLIC API
	/**
	 * Returns an array of expressions ordered by their translated
	 * labels and optionally filtered by context
	 *
	 * @autodoc
	 * @context.hint Expression context with which to filter the results
	 */
	public array function listExpressions( string context="" ) {
		var allExpressions  = _getExpressions();
		var list            = [];
		var filterOnContext = arguments.context.len() > 0;

		for( var expressionId in allExpressions ) {
			var contexts = allExpressions[ expressionId ].contexts ?: [];

			if ( !filterOnContext || contexts.findNoCase( arguments.context ) || contexts.findNoCase( "global" ) ) {
				list.append( getExpression( expressionId ) );
			}
		}

		list.sort( function( a, b ){
			return a.label > b.label ? 1 : -1;
		} );

		return list;
	}


	/**
	 * Returns a structure with all relevant info about the expression
	 * including:
	 * \n
	 * * fields
	 * * contexts
	 * * translated label
	 * * translated expression text
	 *
	 * @autodoc
	 * @expressionId.hint ID of the expression, e.g. "loggedIn.global"
	 */
	public struct function getExpression( required string expressionId ) {
		_throwOnMissingExpression( arguments.expressionId );

		var expressions = _getExpressions();
		var expression  = Duplicate( expressions[ arguments.expressionId ] );

		expression.id     = expressionId;
		expression.label  = getExpressionLabel( expressionId );
		expression.text   = getExpressionText( expressionId );
		expression.fields = expression.fields ?: {};

		for( var fieldName in expression.fields ) {
			expression.fields[ fieldName ].defaultLabel = getDefaultFieldLabel( expressionId, fieldName );
		}

		return expression;
	}

	/**
	 * Returns a translated label for the given expression ID. The label
	 * is shown when rendering the expression in the list of optional
	 * expressions to use for the administrator. e.g.
	 * \n
	 * > User is logged in
	 *
	 * @autodoc
	 * @expressionId.hint ID of the expression, e.g. "loggedIn.global"
	 */
	public string function getExpressionLabel( required string expressionId ) {
		return $translateResource(
			  uri          = "rules.expressions.#arguments.expressionId#:label"
			, defaultValue = arguments.expressionId
		);
	}

	/**
	 * Returns a translated expression text for the given expression ID.
	 * Expression text is the text with placeholders that the administrator
	 * will see when building a condition. e.g.
	 * \n
	 * > User {_is} logged in
	 *
	 * @autodoc
	 * @expressionId.hint ID of the expression, e.g. "loggedIn.global"
	 */
	public string function getExpressionText( required string expressionId ) {
		return $translateResource(
			  uri          = "rules.expressions.#arguments.expressionId#:text"
			, defaultValue = arguments.expressionId
		);
	}

	/**
	 * Returns the default label for an expression field. This label is used when
	 * an administrator has not yet configured the field after inserting an expression
	 * into their condition builder. e.g.
	 * \n
	 * > Choose an event
	 *
	 * @audotodoc
	 * @expressionId.hint ID of the expression who's field we want to get the label of
	 * @fieldName.hint    Name of the field
	 */
	public string function getDefaultFieldLabel( required string expressionId, required string fieldName ) {
		var defaultFieldLabel = $translateResource( uri="rules.fields:#arguments.fieldName#.label", defaultValue=arguments.fieldName );

		return $translateResource( uri="rules.expressions.#arguments.expressionId#:field.#arguments.fieldName#.label", defaultValue=defaultFieldLabel );
	}

	/**
	 * Evaluates an expression, returning true or false,
	 * using the passed context, payload and field configuration.
	 *
	 * @autodoc
	 * @expressionId.hint     The ID of the expression to evaluate
	 * @context.hint          The context in which the expression is being evaluated. e.g. 'request', 'workflow' or 'marketing-automation'
	 * @payload.hint          A structure of data representing a payload against which the expression can be evaluated
	 * @configuredFields.hint A structure of fields configured for the expression instance being evaluated
	 */
	public boolean function evaluateExpression(
		  required string expressionId
		, required string context
		, required struct payload
		, required struct configuredFields
	) {
		_throwOnMissingExpression( expressionId );

		var handlerAction = "rules.expressions." & arguments.expressionId;
		var eventArgs     = { context=arguments.context, payload=arguments.payload };

		eventArgs.append( arguments.configuredFields );

		var result = $getColdbox().runEvent(
			  event          = handlerAction
			, private        = true
			, prePostExempt  = true
			, eventArguments = eventArgs
		);

		return result;
	}

// PRIVATE HELPERS
	private void function _throwOnMissingExpression( required string expressionid ) {
		var expressions = _getExpressions();

		if ( !expressions.keyExists( arguments.expressionId ) ) {
			throw( type="preside.rule.expression.not.found", message="The expression [#arguments.expressionId#] could not be found." );
		}
	}

// GETTERS AND SETTERS
	private struct function _getExpressions() {
		return _expressions;
	}
	private void function _setExpressions( required struct expressions ) {
		_expressions = arguments.expressions;
	}
}