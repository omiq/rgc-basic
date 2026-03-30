/**
 * Gutenberg block editor script (WordPress packages as wp.* globals).
 */
( function ( wp ) {
	'use strict';

	var registerBlockType = wp.blocks.registerBlockType;
	var el = wp.element.createElement;
	var Fragment = wp.element.Fragment;
	var __ = wp.i18n.__;
	var useBlockProps = wp.blockEditor.useBlockProps;
	var InspectorControls = wp.blockEditor.InspectorControls;
	var PanelBody = wp.components.PanelBody;
	var TextareaControl = wp.components.TextareaControl;
	var ToggleControl = wp.components.ToggleControl;
	var TextControl = wp.components.TextControl;
	var ServerSideRender = wp.serverSideRender;

	registerBlockType( 'rgc-basic/tutorial-embed', {
		edit: function ( props ) {
			var attributes = props.attributes;
			var setAttributes = props.setAttributes;
			var blockProps = useBlockProps( {
				className: 'rgc-basic-tutorial-block-editor',
			} );

			return el(
				Fragment,
				null,
				el(
					InspectorControls,
					null,
					el(
						PanelBody,
						{ title: __( 'Embed options', 'rgc-basic-tutorial-block' ), initialOpen: true },
						el( ToggleControl, {
							label: __( 'Show code editor', 'rgc-basic-tutorial-block' ),
							checked: !! attributes.showEditor,
							onChange: function ( v ) {
								setAttributes( { showEditor: v } );
							},
						} ),
						el( ToggleControl, {
							label: __( 'Show pause / stop', 'rgc-basic-tutorial-block' ),
							checked: !! attributes.showPauseStop,
							onChange: function ( v ) {
								setAttributes( { showPauseStop: v } );
							},
						} ),
						el( ToggleControl, {
							label: __( 'Show VFS upload / download', 'rgc-basic-tutorial-block' ),
							checked: !! attributes.showVfsTools,
							onChange: function ( v ) {
								setAttributes( { showVfsTools: v } );
							},
						} ),
						el( TextControl, {
							label: __( 'Editor min height (CSS)', 'rgc-basic-tutorial-block' ),
							value: attributes.editorMinHeight || '120px',
							onChange: function ( v ) {
								setAttributes( { editorMinHeight: v } );
							},
						} ),
						el( TextControl, {
							label: __( 'Output min height (CSS)', 'rgc-basic-tutorial-block' ),
							value: attributes.outputMinHeight || '100px',
							onChange: function ( v ) {
								setAttributes( { outputMinHeight: v } );
							},
						} )
					)
				),
				el(
					'div',
					blockProps,
					el( TextareaControl, {
						label: __( 'BASIC program', 'rgc-basic-tutorial-block' ),
						value: attributes.program || '',
						onChange: function ( v ) {
							setAttributes( { program: v } );
						},
						rows: 12,
						style: { fontFamily: 'monospace' },
					} ),
					el( ServerSideRender, {
						block: 'rgc-basic/tutorial-embed',
						attributes: attributes,
					} )
				)
			);
		},
		save: function () {
			return null;
		},
	} );
} )( window.wp );
