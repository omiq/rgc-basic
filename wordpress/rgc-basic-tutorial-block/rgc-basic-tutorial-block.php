<?php
/**
 * Plugin Name:       RGC-BASIC Tutorial Embed
 * Description:       Gutenberg block to embed RGC-BASIC interpreters (WASM) in posts and pages. Upload modular WASM assets to the plugin or set a custom base URL.
 * Version:           1.0.0
 * Requires at least: 6.0
 * Requires PHP:      7.4
 * Author:            RGC-BASIC
 * License:           GPL-2.0-or-later
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain:       rgc-basic-tutorial-block
 *
 * @package RGC_Basic_Tutorial_Block
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( 'RGC_BASIC_TUTORIAL_BLOCK_VERSION', '1.0.0' );
define( 'RGC_BASIC_TUTORIAL_BLOCK_DIR', plugin_dir_path( __FILE__ ) );
define( 'RGC_BASIC_TUTORIAL_BLOCK_URL', plugin_dir_url( __FILE__ ) );

/**
 * Base URL where basic-modular.js and basic-modular.wasm are served (trailing slash).
 */
function rgc_basic_tutorial_wasm_base_url() {
	$opt = get_option( 'rgc_basic_tutorial_wasm_base_url', '' );
	$opt = is_string( $opt ) ? trim( $opt ) : '';
	if ( $opt !== '' ) {
		return trailingslashit( $opt );
	}
	/**
	 * Filter: override WASM asset base URL (must end with / or be empty to use plugin default).
	 */
	$filtered = apply_filters( 'rgc_basic_tutorial_wasm_base_url', '' );
	if ( is_string( $filtered ) && $filtered !== '' ) {
		return trailingslashit( $filtered );
	}
	return RGC_BASIC_TUTORIAL_BLOCK_URL . 'assets/wasm/';
}

/**
 * Whether local WASM files exist under the plugin (so we can show an admin notice).
 */
function rgc_basic_tutorial_wasm_files_present() {
	$wasm = RGC_BASIC_TUTORIAL_BLOCK_DIR . 'assets/wasm/basic-modular.wasm';
	$js   = RGC_BASIC_TUTORIAL_BLOCK_DIR . 'assets/wasm/basic-modular.js';
	return is_readable( $wasm ) && is_readable( $js );
}

/**
 * Register and enqueue scripts/styles when the block appears (editor + front).
 */
function rgc_basic_tutorial_register_assets() {
	$ver_main = RGC_BASIC_TUTORIAL_BLOCK_VERSION;
	$wasm_js  = RGC_BASIC_TUTORIAL_BLOCK_DIR . 'assets/wasm/basic-modular.js';
	if ( is_readable( $wasm_js ) ) {
		$ver_main = (string) filemtime( $wasm_js );
	}

	wp_register_style(
		'rgc-basic-tutorial-embed-frontend',
		RGC_BASIC_TUTORIAL_BLOCK_URL . 'build/block-frontend.css',
		array(),
		file_exists( RGC_BASIC_TUTORIAL_BLOCK_DIR . 'build/block-frontend.css' )
			? (string) filemtime( RGC_BASIC_TUTORIAL_BLOCK_DIR . 'build/block-frontend.css' )
			: RGC_BASIC_TUTORIAL_BLOCK_VERSION
	);

	wp_register_script(
		'rgc-basic-vfs-helpers',
		RGC_BASIC_TUTORIAL_BLOCK_URL . 'assets/js/vfs-helpers.js',
		array(),
		file_exists( RGC_BASIC_TUTORIAL_BLOCK_DIR . 'assets/js/vfs-helpers.js' )
			? (string) filemtime( RGC_BASIC_TUTORIAL_BLOCK_DIR . 'assets/js/vfs-helpers.js' )
			: RGC_BASIC_TUTORIAL_BLOCK_VERSION,
		true
	);

	wp_register_script(
		'rgc-basic-tutorial-embed',
		RGC_BASIC_TUTORIAL_BLOCK_URL . 'assets/js/tutorial-embed.js',
		array( 'rgc-basic-vfs-helpers' ),
		file_exists( RGC_BASIC_TUTORIAL_BLOCK_DIR . 'assets/js/tutorial-embed.js' )
			? (string) filemtime( RGC_BASIC_TUTORIAL_BLOCK_DIR . 'assets/js/tutorial-embed.js' )
			: RGC_BASIC_TUTORIAL_BLOCK_VERSION,
		true
	);

	wp_register_script(
		'rgc-basic-tutorial-embed-init',
		RGC_BASIC_TUTORIAL_BLOCK_URL . 'build/frontend-init.js',
		array( 'rgc-basic-tutorial-embed' ),
		file_exists( RGC_BASIC_TUTORIAL_BLOCK_DIR . 'build/frontend-init.js' )
			? (string) filemtime( RGC_BASIC_TUTORIAL_BLOCK_DIR . 'build/frontend-init.js' )
			: RGC_BASIC_TUTORIAL_BLOCK_VERSION,
		true
	);

	wp_register_script(
		'rgc-basic-wasm-modular',
		rgc_basic_tutorial_wasm_base_url() . 'basic-modular.js',
		array(),
		$ver_main,
		true
	);
}

add_action( 'init', 'rgc_basic_tutorial_register_assets' );

/**
 * Enqueue WASM loader before our embed (tutorial-embed loads it async; registering helps dependency order if extended).
 */
function rgc_basic_tutorial_enqueue_block_assets() {
	if ( ! has_block( 'rgc-basic/tutorial-embed' ) ) {
		return;
	}
	wp_enqueue_style( 'rgc-basic-tutorial-embed-frontend' );
	wp_enqueue_script( 'rgc-basic-tutorial-embed-init' );
	wp_localize_script(
		'rgc-basic-tutorial-embed-init',
		'rgcBasicTutorialBlock',
		array(
			'baseUrl' => rgc_basic_tutorial_wasm_base_url(),
		)
	);
}

add_action( 'enqueue_block_assets', 'rgc_basic_tutorial_enqueue_block_assets' );

/**
 * Editor-only assets for the block UI.
 */
function rgc_basic_tutorial_enqueue_editor_assets() {
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( ! $screen || ! $screen->is_block_editor() ) {
		return;
	}
	wp_enqueue_style( 'rgc-basic-tutorial-embed-frontend' );
	wp_enqueue_script( 'rgc-basic-tutorial-embed-init' );
	wp_localize_script(
		'rgc-basic-tutorial-embed-init',
		'rgcBasicTutorialBlock',
		array(
			'baseUrl' => rgc_basic_tutorial_wasm_base_url(),
		)
	);
}

add_action( 'enqueue_block_editor_assets', 'rgc_basic_tutorial_enqueue_editor_assets' );

/**
 * Register block type from block.json + PHP render callback.
 */
function rgc_basic_tutorial_register_block() {
	wp_register_script(
		'rgc-basic-tutorial-block-editor',
		RGC_BASIC_TUTORIAL_BLOCK_URL . 'build/block-editor.js',
		array(
			'wp-blocks',
			'wp-element',
			'wp-block-editor',
			'wp-components',
			'wp-i18n',
			'wp-server-side-render',
		),
		file_exists( RGC_BASIC_TUTORIAL_BLOCK_DIR . 'build/block-editor.js' )
			? (string) filemtime( RGC_BASIC_TUTORIAL_BLOCK_DIR . 'build/block-editor.js' )
			: RGC_BASIC_TUTORIAL_BLOCK_VERSION,
		true
	);

	register_block_type(
		RGC_BASIC_TUTORIAL_BLOCK_DIR . 'block.json',
		array(
			'render_callback' => 'rgc_basic_tutorial_render_block',
		)
	);
}

add_action( 'init', 'rgc_basic_tutorial_register_block' );

/**
 * @param array    $attributes Block attributes.
 * @param string   $content    Inner blocks (unused).
 * @param WP_Block $block      Block instance.
 * @return string
 */
function rgc_basic_tutorial_render_block( $attributes, $content, $block ) {
	wp_enqueue_style( 'rgc-basic-tutorial-embed-frontend' );
	wp_enqueue_script( 'rgc-basic-tutorial-embed-init' );
	wp_localize_script(
		'rgc-basic-tutorial-embed-init',
		'rgcBasicTutorialBlock',
		array(
			'baseUrl' => rgc_basic_tutorial_wasm_base_url(),
		)
	);

	$defaults = array(
		'program'        => "10 PRINT \"HELLO\"\n20 END\n",
		'showEditor'     => true,
		'showPauseStop'  => true,
		'showVfsTools'   => true,
		'editorMinHeight'=> '120px',
		'outputMinHeight'=> '100px',
	);

	$a = wp_parse_args( $attributes, $defaults );

	$program = isset( $a['program'] ) ? (string) $a['program'] : $defaults['program'];
	// Normalise line endings for JSON.
	$program = str_replace( array( "\r\n", "\r" ), "\n", $program );

	$opts = array(
		'program'         => $program,
		'showEditor'      => (bool) $a['showEditor'],
		'showPauseStop'   => (bool) $a['showPauseStop'],
		'showVfsTools'    => (bool) $a['showVfsTools'],
		'editorMinHeight' => (string) $a['editorMinHeight'],
		'outputMinHeight' => (string) $a['outputMinHeight'],
		'baseUrl'         => rgc_basic_tutorial_wasm_base_url(),
	);

	$opts = apply_filters( 'rgc_basic_tutorial_embed_options', $opts, $attributes, $block );

	$json = wp_json_encode(
		$opts,
		JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_UNESCAPED_UNICODE
	);
	if ( ! is_string( $json ) ) {
		$json = '{}';
	}

	$wrapper = get_block_wrapper_attributes(
		array(
			'class' => 'rgc-basic-tutorial-block-root',
		)
	);

	return sprintf(
		'<div %1$s><script type="application/json" class="rgc-basic-embed-config">%2$s</script></div>',
		$wrapper,
		$json
	);
}

/**
 * Settings: optional WASM base URL.
 */
function rgc_basic_tutorial_register_settings() {
	register_setting(
		'rgc_basic_tutorial',
		'rgc_basic_tutorial_wasm_base_url',
		array(
			'type'              => 'string',
			'sanitize_callback' => 'rgc_basic_tutorial_sanitize_wasm_base_url',
			'default'           => '',
		)
	);
}

add_action( 'admin_init', 'rgc_basic_tutorial_register_settings' );

/**
 * @param mixed $value Raw option.
 * @return string Empty or absolute URL with trailing slash.
 */
function rgc_basic_tutorial_sanitize_wasm_base_url( $value ) {
	if ( ! is_string( $value ) ) {
		return '';
	}
	$value = trim( $value );
	if ( $value === '' ) {
		return '';
	}
	return trailingslashit( esc_url_raw( $value ) );
}

function rgc_basic_tutorial_add_settings_page() {
	add_options_page(
		__( 'RGC-BASIC Tutorial', 'rgc-basic-tutorial-block' ),
		__( 'RGC-BASIC Tutorial', 'rgc-basic-tutorial-block' ),
		'manage_options',
		'rgc-basic-tutorial',
		'rgc_basic_tutorial_render_settings_page'
	);
}

add_action( 'admin_menu', 'rgc_basic_tutorial_add_settings_page' );

function rgc_basic_tutorial_render_settings_page() {
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}
	if ( isset( $_POST['rgc_basic_tutorial_save'] ) && check_admin_referer( 'rgc_basic_tutorial_settings' ) ) {
		$url = isset( $_POST['rgc_basic_tutorial_wasm_base_url'] ) ? wp_unslash( $_POST['rgc_basic_tutorial_wasm_base_url'] ) : '';
		$url = rgc_basic_tutorial_sanitize_wasm_base_url( $url );
		update_option( 'rgc_basic_tutorial_wasm_base_url', $url );
		echo '<div class="updated"><p>' . esc_html__( 'Settings saved.', 'rgc-basic-tutorial-block' ) . '</p></div>';
	}
	$val   = get_option( 'rgc_basic_tutorial_wasm_base_url', '' );
	$local = rgc_basic_tutorial_wasm_files_present();
	?>
	<div class="wrap">
		<h1><?php echo esc_html( get_admin_page_title() ); ?></h1>
		<p>
			<?php
			if ( $local ) {
				esc_html_e( 'WASM files detected in the plugin. Embeds will load from the plugin URL unless you override below.', 'rgc-basic-tutorial-block' );
			} else {
				esc_html_e( 'No basic-modular.js / basic-modular.wasm in the plugin. Copy build output (see readme) or set a full URL to a directory that hosts those files.', 'rgc-basic-tutorial-block' );
			}
			?>
		</p>
		<form method="post">
			<?php wp_nonce_field( 'rgc_basic_tutorial_settings' ); ?>
			<table class="form-table">
				<tr>
					<th scope="row"><label for="rgc_basic_tutorial_wasm_base_url"><?php esc_html_e( 'WASM base URL (optional)', 'rgc-basic-tutorial-block' ); ?></label></th>
					<td>
						<input type="url" class="large-text" name="rgc_basic_tutorial_wasm_base_url" id="rgc_basic_tutorial_wasm_base_url" value="<?php echo esc_attr( $val ); ?>" placeholder="https://example.com/rgc-basic-wasm/" />
						<p class="description"><?php esc_html_e( 'Must include trailing slash. Leave empty to use wp-content/.../assets/wasm/ in this plugin.', 'rgc-basic-tutorial-block' ); ?></p>
					</td>
				</tr>
			</table>
			<?php submit_button( __( 'Save', 'rgc-basic-tutorial-block' ), 'primary', 'rgc_basic_tutorial_save' ); ?>
		</form>
	</div>
	<?php
}

function rgc_basic_tutorial_admin_notice_missing_wasm() {
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}
	if ( rgc_basic_tutorial_wasm_files_present() ) {
		return;
	}
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( ! $screen || $screen->id !== 'plugins' ) {
		return;
	}
	echo '<div class="notice notice-warning"><p>';
	echo esc_html__( 'RGC-BASIC Tutorial Embed: add basic-modular.js and basic-modular.wasm to wp-content/plugins/rgc-basic-tutorial-block/assets/wasm/ (run copy-web-assets.sh from the plugin folder) or configure Settings → RGC-BASIC Tutorial.', 'rgc-basic-tutorial-block' );
	echo '</p></div>';
}

add_action( 'admin_notices', 'rgc_basic_tutorial_admin_notice_missing_wasm' );
