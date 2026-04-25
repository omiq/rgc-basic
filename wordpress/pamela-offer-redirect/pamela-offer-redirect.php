<?php
/**
 * Plugin Name: Pamela Offer Redirect
 * Description: Time-window redirects for offer pages, with admin editor
 * Version:     1.1.0
 * Author:      Chris Garrett
 */


/* Add ?offer_debug=1 trace to verify the hook is firing on Kinsta. */

if (!defined('ABSPATH')) { exit; }

const PAMELA_OFFER_OPTION = 'pamela_offer_redirects';

/**
 * Default offers used the first time the plugin runs (before the admin saves anything).
 */
function pamela_offer_defaults() {
    return [
        [
            'slug'        => 'reiki-professional-bundle',
            'start'       => '2026-04-21 00:00:00',
            'end'         => '2026-04-22 23:59:59',
            'redirect_to' => 'reiki-professional-bundle-final',
        ],
        [
            'slug'        => 'reiki-professional-bundle-final',
            'start'       => '2026-04-23 00:00:00',
            'end'         => '2026-04-24 23:59:59',
            'redirect_to' => 'reiki-professional-academy',
        ],
        [
            'slug'        => 'reiki-professional-bundle-reopen',
            'start'       => '2026-04-26 00:00:00',
            'end'         => '2026-04-27 23:59:59',
            'redirect_to' => 'reiki-professional-academy',
        ],
    ];
}

function pamela_offer_get_offers() {
    $stored = get_option(PAMELA_OFFER_OPTION, null);
    if (!is_array($stored)) {
        return pamela_offer_defaults();
    }
    return $stored;
}

/* ------------------------------------------------------------------ */
/* Frontend: header markers + template_redirect logic                  */
/* ------------------------------------------------------------------ */

add_action('send_headers', function () {
    if (!headers_sent()) {
        header('X-Pamela-Offer-Redirect: loaded');
    }
});

add_action('template_redirect', function () {
    if (is_admin()) { return; }

    $debug = isset($_GET['offer_debug']);
    $log   = [];
    $emit  = function ($msg) use (&$log) {
        error_log('[pamela-offer] ' . $msg);
        $log[] = $msg;
    };

    $wp_timezone = wp_timezone();
    $now = new DateTime('now', $wp_timezone);

    $request_path = trim(parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH), '/');

    $offers = pamela_offer_get_offers();

    $emit('template_redirect fired');
    $emit('Request path: ' . $request_path);
    $emit('Now: ' . $now->format('Y-m-d H:i:s T'));

    if (!headers_sent()) {
        header('X-Pamela-Offer-Fired: yes');
        header('X-Pamela-Offer-Path: ' . $request_path);
    }

    foreach ($offers as $offer) {
        if (empty($offer['slug'])) { continue; }

        $matches_page = is_page($offer['slug']);
        $matches_path = ($request_path === trim($offer['slug'], '/'));

        $emit(
            'Checking ' . $offer['slug'] .
            ' | is_page=' . ($matches_page ? 'yes' : 'no') .
            ' | path_match=' . ($matches_path ? 'yes' : 'no')
        );

        if ($matches_page || $matches_path) {
            try {
                $start = new DateTime($offer['start'], $wp_timezone);
                $end   = new DateTime($offer['end'], $wp_timezone);
            } catch (Exception $e) {
                $emit('Bad date on ' . $offer['slug'] . ': ' . $e->getMessage());
                continue;
            }

            $emit('Start: ' . $start->format('Y-m-d H:i:s T'));
            $emit('End: ' . $end->format('Y-m-d H:i:s T'));

            if ($now < $start || $now > $end) {
                $target = home_url('/' . trim($offer['redirect_to'], '/') . '/');
                $emit('Redirecting to: ' . $target);

                if ($debug) {
                    header('Content-Type: text/plain; charset=utf-8');
                    echo "PAMELA OFFER REDIRECT — DEBUG MODE\n";
                    echo "Would redirect to: {$target}\n\n";
                    echo implode("\n", $log), "\n";
                    exit;
                }

                nocache_headers();
                wp_safe_redirect($target, 302);
                exit;
            }

            $emit('Within active window, no redirect');
        }
    }

    if ($debug) {
        header('Content-Type: text/plain; charset=utf-8');
        echo "PAMELA OFFER REDIRECT — DEBUG MODE\n";
        echo "No matching offer slug / no redirect triggered.\n\n";
        echo implode("\n", $log), "\n";
        exit;
    }
}, 1);

/* ------------------------------------------------------------------ */
/* Admin: Settings → Offer Redirects                                   */
/* ------------------------------------------------------------------ */

add_action('admin_menu', function () {
    add_options_page(
        'Offer Redirects',
        'Offer Redirects',
        'manage_options',
        'pamela-offer-redirect',
        'pamela_offer_render_admin_page'
    );
});

add_action('admin_post_pamela_offer_save', 'pamela_offer_handle_save');

function pamela_offer_handle_save() {
    if (!current_user_can('manage_options')) {
        wp_die('Not allowed.');
    }
    check_admin_referer('pamela_offer_save');

    $rows = $_POST['offers'] ?? [];
    $clean = [];

    if (is_array($rows)) {
        foreach ($rows as $row) {
            $slug        = sanitize_title(trim($row['slug'] ?? ''));
            $start       = trim($row['start'] ?? '');
            $end         = trim($row['end'] ?? '');
            $redirect_to = sanitize_title(trim($row['redirect_to'] ?? ''));

            if ($slug === '' && $redirect_to === '' && $start === '' && $end === '') {
                continue; // blank row
            }
            if ($slug === '' || $redirect_to === '' || $start === '' || $end === '') {
                continue; // skip incomplete — could add notice, but simplest is to drop
            }

            $clean[] = [
                'slug'        => $slug,
                'start'       => $start,
                'end'         => $end,
                'redirect_to' => $redirect_to,
            ];
        }
    }

    update_option(PAMELA_OFFER_OPTION, $clean);

    wp_safe_redirect(add_query_arg(
        ['page' => 'pamela-offer-redirect', 'updated' => '1'],
        admin_url('options-general.php')
    ));
    exit;
}

function pamela_offer_render_admin_page() {
    if (!current_user_can('manage_options')) { return; }

    $offers = pamela_offer_get_offers();
    // pad with blank rows so admin can add new entries
    $blank = ['slug' => '', 'start' => '', 'end' => '', 'redirect_to' => ''];
    $rows = array_merge($offers, [$blank, $blank, $blank]);

    $tz = wp_timezone_string();
    ?>
    <div class="wrap">
        <h1>Offer Redirects</h1>

        <?php if (!empty($_GET['updated'])): ?>
            <div class="notice notice-success is-dismissible"><p>Saved.</p></div>
        <?php endif; ?>

        <div class="card" style="max-width:900px;padding:1em 1.5em;">
            <h2>How it works</h2>
            <ol>
                <li>One row per offer page. Slug = the page slug (no slashes), e.g. <code>reiki-professional-bundle-final</code>.</li>
                <li><strong>Start / End</strong> format: <code>YYYY-MM-DD HH:MM:SS</code>. Site timezone is <code><?php echo esc_html($tz); ?></code>.</li>
                <li>When a visitor hits the slug page <em>outside</em> the start→end window, they get 302-redirected to <strong>Redirect To</strong>.</li>
                <li><em>Inside</em> the window = no redirect, the page shows normally.</li>
                <li>Leave a row completely blank to ignore it. Incomplete rows are dropped on save.</li>
            </ol>
            <h3>Diagnostics</h3>
            <ul style="list-style:disc;padding-left:1.5em;">
                <li>Append <code>?offer_debug=1</code> to any offer URL to see the decision trace instead of redirecting.</li>
                <li>Response headers on every front-end request: <code>X-Pamela-Offer-Redirect: loaded</code> (plugin active) and <code>X-Pamela-Offer-Fired: yes</code> (template_redirect ran — i.e. cache did not serve a stale copy).</li>
                <li>If <code>X-Pamela-Offer-Fired</code> is missing but the plugin is active, Kinsta/CDN page cache is serving the URL — add it to the cache-exclusion list and purge.</li>
            </ul>
        </div>

        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" style="margin-top:1.5em;">
            <input type="hidden" name="action" value="pamela_offer_save" />
            <?php wp_nonce_field('pamela_offer_save'); ?>

            <table class="widefat striped" style="max-width:1100px;">
                <thead>
                    <tr>
                        <th style="width:26%;">Page slug</th>
                        <th style="width:20%;">Start (<?php echo esc_html($tz); ?>)</th>
                        <th style="width:20%;">End (<?php echo esc_html($tz); ?>)</th>
                        <th style="width:26%;">Redirect to (slug)</th>
                    </tr>
                </thead>
                <tbody>
                <?php foreach ($rows as $i => $row): ?>
                    <tr>
                        <td>
                            <input type="text" name="offers[<?php echo $i; ?>][slug]"
                                   value="<?php echo esc_attr($row['slug']); ?>"
                                   class="regular-text" placeholder="offer-page-slug" />
                        </td>
                        <td>
                            <input type="text" name="offers[<?php echo $i; ?>][start]"
                                   value="<?php echo esc_attr($row['start']); ?>"
                                   class="regular-text" placeholder="2026-04-23 00:00:00" />
                        </td>
                        <td>
                            <input type="text" name="offers[<?php echo $i; ?>][end]"
                                   value="<?php echo esc_attr($row['end']); ?>"
                                   class="regular-text" placeholder="2026-04-24 23:59:59" />
                        </td>
                        <td>
                            <input type="text" name="offers[<?php echo $i; ?>][redirect_to]"
                                   value="<?php echo esc_attr($row['redirect_to']); ?>"
                                   class="regular-text" placeholder="destination-slug" />
                        </td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>

            <p style="margin-top:1em;">
                <button type="submit" class="button button-primary">Update offers</button>
                <span style="margin-left:1em;color:#666;">Need more rows? Save first — three blank rows are added every time this page loads.</span>
            </p>
        </form>
    </div>
    <?php
}
