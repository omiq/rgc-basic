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

	/*
	 * Self-sufficient registration: include title/category/icon/attributes so the
	 * block appears in the inserter even when server-side register_block_type()
	 * fails (e.g. blocks/gfx/block.json not deployed, opcache stale, etc.).
	 * WP still merges any server-side metadata by name on top when present.
	 */
	registerBlockType( 'rgc-basic/gfx-embed', {
		apiVersion: 3,
		title: __( 'RGC-BASIC GFX embed', 'rgc-basic-tutorial-block' ),
		description: __(
			'Interactive RGC-BASIC runtime (raylib/WebGL2 — sprites, bitmap modes, audio, scroll zones). Host basic-raylib.js and basic-raylib.wasm on HTTPS.',
			'rgc-basic-tutorial-block'
		),
		category: 'widgets',
		icon: 'format-image',
		keywords: [ 'rgc', 'rgc-basic', 'basic', 'canvas', 'sprite', 'gfx', 'embed', 'petscii' ],
		supports: { html: false, align: true },
		attributes: {
			program:          { type: 'string',  default: '10 END\n' },
			showEditor:       { type: 'boolean', default: true },
			showControls:     { type: 'boolean', default: true },
			showFullscreen:   { type: 'boolean', default: true },
			showVfsTools:     { type: 'boolean', default: true },
			posterImageUrl:   { type: 'string',  default: '' },
			interpreterFlags: { type: 'string',  default: '-petscii -charset lower -palette ansi -columns 40' },
			autorun:          { type: 'boolean', default: false },
			canvasMode:       { type: 'string',  default: 'visible' },
		},
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
						} ),
						el( ToggleControl, {
							label: __( 'Auto-run on page load', 'rgc-basic-tutorial-block' ),
							help: __(
								'Start the program as soon as WASM is ready — no Run button click. Combine with Canvas mode = offscreen/hidden for landing-page animations or headless tools. Audio still waits for a user gesture.',
								'rgc-basic-tutorial-block'
							),
							checked: !! attributes.autorun,
							onChange: function ( v ) {
								setAttributes( { autorun: v } );
							},
						} ),
						el( 'div', { style: { marginTop: '8px' } },
							el( 'label', { style: { display: 'block', marginBottom: '4px', fontSize: '11px', fontWeight: '500', textTransform: 'uppercase' } },
								__( 'Canvas mode', 'rgc-basic-tutorial-block' )
							),
							el( 'select', {
								value: attributes.canvasMode || 'visible',
								onChange: function ( e ) {
									setAttributes( { canvasMode: e.target.value } );
								},
								style: { width: '100%' },
							},
								el( 'option', { value: 'visible' },   __( 'Visible (normal)', 'rgc-basic-tutorial-block' ) ),
								el( 'option', { value: 'offscreen' }, __( 'Offscreen (hidden but rendering)', 'rgc-basic-tutorial-block' ) ),
								el( 'option', { value: 'hidden' },    __( 'Hidden (headless — no GL)', 'rgc-basic-tutorial-block' ) )
							),
							el( 'p', { style: { fontSize: '12px', color: '#757575', marginTop: '4px' } },
								__( 'Offscreen keeps WebGL rendering (needed for raylib) but hides the canvas. Hidden drops the canvas entirely; only useful for non-gfx utility code.', 'rgc-basic-tutorial-block' )
							)
						)
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
