/**
 * RGC-BASIC GFX embed — Gutenberg editor (rgc-basic/gfx-embed ONLY).
 * If registerBlockType below says tutorial-embed, this file was overwritten by mistake; restore from git.
 * Terminal block lives in block-editor.js only.
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

	registerBlockType( 'rgc-basic/gfx-embed', {
		edit: function ( props ) {
			var attributes = props.attributes;
			var setAttributes = props.setAttributes;
			var blockProps = useBlockProps( {
				className: 'rgc-basic-gfx-block-editor',
			} );

			return el(
				Fragment,
				null,
				el(
					InspectorControls,
					null,
					el(
						PanelBody,
						{ title: __( 'GFX embed options', 'rgc-basic-tutorial-block' ), initialOpen: true },
						el( ToggleControl, {
							label: __( 'Show code editor', 'rgc-basic-tutorial-block' ),
							checked: !! attributes.showEditor,
							onChange: function ( v ) {
								setAttributes( { showEditor: v } );
							},
						} ),
						el( ToggleControl, {
							label: __( 'Show Run / Pause / Stop / Zoom', 'rgc-basic-tutorial-block' ),
							checked: !! attributes.showControls,
							onChange: function ( v ) {
								setAttributes( { showControls: v } );
							},
						} ),
						el( ToggleControl, {
							label: __( 'Show fullscreen button', 'rgc-basic-tutorial-block' ),
							checked: !! attributes.showFullscreen,
							onChange: function ( v ) {
								setAttributes( { showFullscreen: v } );
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
							label: __( 'Poster image URL (optional)', 'rgc-basic-tutorial-block' ),
							help: __(
								'If set, WASM loads when the visitor clicks Run on the poster (saves bandwidth).',
								'rgc-basic-tutorial-block'
							),
							value: attributes.posterImageUrl || '',
							onChange: function ( v ) {
								setAttributes( { posterImageUrl: v } );
							},
						} ),
						el( TextControl, {
							label: __( 'Interpreter flags', 'rgc-basic-tutorial-block' ),
							help: __( 'Example: -petscii -charset lower -palette ansi -columns 40', 'rgc-basic-tutorial-block' ),
							value: attributes.interpreterFlags || '',
							onChange: function ( v ) {
								setAttributes( { interpreterFlags: v } );
							},
						} )
					)
				),
				el(
					'div',
					blockProps,
					el( TextareaControl, {
						label: __( 'BASIC program (canvas / sprites)', 'rgc-basic-tutorial-block' ),
						value: attributes.program || '',
						onChange: function ( v ) {
							setAttributes( { program: v } );
						},
						rows: 14,
						style: { fontFamily: 'monospace' },
					} ),
					el( ServerSideRender, {
						block: 'rgc-basic/gfx-embed',
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
