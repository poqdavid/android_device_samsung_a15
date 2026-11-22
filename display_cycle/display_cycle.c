/*
 *	This file is part of the OrangeFox Recovery Project
 *	Copyright (C) 2026 The OrangeFox Recovery Project
 *
 *	OrangeFox is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 3 of the License, or
 *	any later version.
 *
 *	OrangeFox is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	This software is released under GPL version 3 or any later version.
 *	See <http://www.gnu.org/licenses/>.
 *
 * display_cycle [off_ms]
 *
 * Turns the display off through DRM, waits off_ms (1000 by default) and
 * turns it on again with a black frame. For the panel this is the same as
 * OrangeFox blanking and unblanking the screen with the power key. When the
 * kernel reports the display off, as it does at boot, it turns it on first
 * (see main).
 *
 * The Zinitix touch controller only reports touches after the panel has
 * been powered down and brought up again by the kernel. At boot the panel is
 * still on from the bootloader, so without this OrangeFox starts with dead
 * touch until the screen is turned off and on once. zinitix_touch.sh runs
 * this before OrangeFox takes the display. It needs to be the DRM master,
 * so it fails while OrangeFox is running.
 *
 * It talks to the kernel with plain ioctls rather than libdrm, so the same
 * source also builds as a static test binary outside the Android tree.
 */

#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#include <drm/drm.h>
#include <drm/drm_mode.h>

#define TAG "display_cycle"
#define DEFAULT_OFF_MS 1000
/*
 * Lets the take-over settle before the display goes off. When this was
 * tested by hand, OrangeFox had held the display for minutes in between.
 */
#define TAKEOVER_SETTLE_MS 500

struct output {
	uint32_t connector_id;
	uint32_t crtc_id;
	struct drm_mode_modeinfo mode;
};

static void log_msg(const char *fmt, ...)
{
	char buf[256];
	va_list ap;
	int len, fd;

	len = snprintf(buf, sizeof(buf), "%s: ", TAG);
	va_start(ap, fmt);
	len += vsnprintf(buf + len, sizeof(buf) - len, fmt, ap);
	va_end(ap);
	if (len >= (int)sizeof(buf) - 1)
		len = sizeof(buf) - 2;
	buf[len++] = '\n';
	buf[len] = '\0';

	fputs(buf, stderr);
	/* init has no console for us, so the kernel log is where this shows up */
	fd = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);
	if (fd >= 0) {
		ssize_t written = write(fd, buf, len);

		(void)written;
		close(fd);
	}
}

static int drm_ioctl(int fd, unsigned long request, void *arg)
{
	int ret;

	do {
		ret = ioctl(fd, request, arg);
	} while (ret == -1 && (errno == EINTR || errno == EAGAIN));
	return ret;
}

static void *alloc_array(uint32_t count, size_t size)
{
	/* calloc(0) may return NULL, which would look like a failure */
	return calloc(count ? count : 1, size);
}

/*
 * The kernel only fills an array if it is big enough, and reports the real
 * count. Ask for the counts first, then retry until a call fits, in case a
 * connector appeared in between.
 */
static int get_resources(int fd, uint32_t **crtcs, uint32_t *n_crtcs,
			 uint32_t **connectors, uint32_t *n_connectors)
{
	struct drm_mode_card_res res;
	uint32_t want_crtcs, want_connectors;
	int tries;

	for (tries = 0; tries < 5; tries++) {
		memset(&res, 0, sizeof(res));
		if (drm_ioctl(fd, DRM_IOCTL_MODE_GETRESOURCES, &res))
			return -1;
		want_crtcs = res.count_crtcs;
		want_connectors = res.count_connectors;

		*crtcs = alloc_array(want_crtcs, sizeof(**crtcs));
		*connectors = alloc_array(want_connectors, sizeof(**connectors));
		if (!*crtcs || !*connectors)
			goto fail;

		memset(&res, 0, sizeof(res));
		res.crtc_id_ptr = (uintptr_t)*crtcs;
		res.count_crtcs = want_crtcs;
		res.connector_id_ptr = (uintptr_t)*connectors;
		res.count_connectors = want_connectors;
		if (drm_ioctl(fd, DRM_IOCTL_MODE_GETRESOURCES, &res))
			goto fail;
		if (res.count_crtcs <= want_crtcs &&
		    res.count_connectors <= want_connectors) {
			*n_crtcs = res.count_crtcs;
			*n_connectors = res.count_connectors;
			return 0;
		}
		free(*crtcs);
		free(*connectors);
	}
	errno = EAGAIN;
	return -1;
fail:
	free(*crtcs);
	free(*connectors);
	return -1;
}

static int get_connector(int fd, uint32_t id, struct drm_mode_get_connector *conn,
			 struct drm_mode_modeinfo **modes, uint32_t **encoders)
{
	uint32_t want_modes, want_encoders;
	int tries;

	for (tries = 0; tries < 5; tries++) {
		/* count_modes 0 also makes the kernel probe the connector */
		memset(conn, 0, sizeof(*conn));
		conn->connector_id = id;
		if (drm_ioctl(fd, DRM_IOCTL_MODE_GETCONNECTOR, conn))
			return -1;
		want_modes = conn->count_modes;
		want_encoders = conn->count_encoders;

		*modes = alloc_array(want_modes, sizeof(**modes));
		*encoders = alloc_array(want_encoders, sizeof(**encoders));
		if (!*modes || !*encoders)
			goto fail;

		memset(conn, 0, sizeof(*conn));
		conn->connector_id = id;
		conn->modes_ptr = (uintptr_t)*modes;
		conn->count_modes = want_modes;
		conn->encoders_ptr = (uintptr_t)*encoders;
		conn->count_encoders = want_encoders;
		if (drm_ioctl(fd, DRM_IOCTL_MODE_GETCONNECTOR, conn))
			goto fail;
		if (conn->count_modes <= want_modes &&
		    conn->count_encoders <= want_encoders)
			return 0;
		free(*modes);
		free(*encoders);
	}
	errno = EAGAIN;
	return -1;
fail:
	free(*modes);
	free(*encoders);
	return -1;
}

static uint32_t crtc_for_encoder(int fd, uint32_t encoder_id, int current,
				 const uint32_t *crtcs, uint32_t n_crtcs)
{
	struct drm_mode_get_encoder enc;
	uint32_t i;

	memset(&enc, 0, sizeof(enc));
	enc.encoder_id = encoder_id;
	if (drm_ioctl(fd, DRM_IOCTL_MODE_GETENCODER, &enc))
		return 0;
	if (current)
		return enc.crtc_id;
	for (i = 0; i < n_crtcs && i < 32; i++)
		if (enc.possible_crtcs & (1u << i))
			return crtcs[i];
	return 0;
}

/*
 * Picks the built-in panel the way OrangeFox does: a connected DSI connector
 * if there is one, otherwise the first connected one, with its preferred
 * mode, driven by the CRTC it already uses or the first one it can use.
 */
static int find_output(int fd, struct output *out)
{
	uint32_t *crtcs = NULL, *connectors = NULL, n_crtcs = 0, n_connectors = 0;
	int found = 0, pass, ret = -1;
	uint32_t i, j;

	if (get_resources(fd, &crtcs, &n_crtcs, &connectors, &n_connectors))
		return -1;

	for (pass = 0; pass < 2 && !found; pass++) {
		for (i = 0; i < n_connectors && !found; i++) {
			struct drm_mode_get_connector conn;
			struct drm_mode_modeinfo *modes = NULL;
			uint32_t *encoders = NULL;
			uint32_t crtc = 0, m = 0;

			if (get_connector(fd, connectors[i], &conn, &modes, &encoders))
				continue;
			if (conn.connection != 1 || conn.count_modes == 0 ||
			    (pass == 0 && conn.connector_type != DRM_MODE_CONNECTOR_DSI))
				goto next;

			for (j = 0; j < conn.count_modes; j++) {
				if (modes[j].type & DRM_MODE_TYPE_PREFERRED) {
					m = j;
					break;
				}
			}
			if (conn.encoder_id)
				crtc = crtc_for_encoder(fd, conn.encoder_id, 1, crtcs, n_crtcs);
			for (j = 0; j < conn.count_encoders && !crtc; j++)
				crtc = crtc_for_encoder(fd, encoders[j], 0, crtcs, n_crtcs);
			if (!crtc)
				goto next;

			out->connector_id = conn.connector_id;
			out->crtc_id = crtc;
			out->mode = modes[m];
			found = 1;
next:
			free(modes);
			free(encoders);
		}
	}
	if (found)
		ret = 0;
	else
		errno = ENODEV;
	free(crtcs);
	free(connectors);
	return ret;
}

static int open_card(struct output *out)
{
	char path[32];
	int i, fd;

	for (i = 0; i < 16; i++) {
		snprintf(path, sizeof(path), "/dev/dri/card%d", i);
		fd = open(path, O_RDWR | O_CLOEXEC);
		if (fd < 0)
			continue;
		if (find_output(fd, out) == 0) {
			log_msg("%s: connector %u on crtc %u, %ux%u", path,
				out->connector_id, out->crtc_id,
				out->mode.hdisplay, out->mode.vdisplay);
			return fd;
		}
		close(fd);
	}
	return -1;
}

static int crtc_active(int fd, uint32_t crtc_id)
{
	struct drm_mode_crtc crtc;

	memset(&crtc, 0, sizeof(crtc));
	crtc.crtc_id = crtc_id;
	if (drm_ioctl(fd, DRM_IOCTL_MODE_GETCRTC, &crtc))
		return -1;
	return crtc.mode_valid ? 1 : 0;
}

/*
 * A CRTC can only be turned on with a framebuffer, so make a black one. The
 * kernel removes it when we exit, and OrangeFox puts its own up when it
 * starts.
 */
static int black_fb(int fd, const struct output *out, uint32_t *fb_id)
{
	struct drm_mode_create_dumb create;
	struct drm_mode_map_dumb map;
	struct drm_mode_fb_cmd fb;
	void *pixels;

	memset(&create, 0, sizeof(create));
	create.width = out->mode.hdisplay;
	create.height = out->mode.vdisplay;
	create.bpp = 32;
	if (drm_ioctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &create))
		return -1;

	/* most drivers hand out zeroed buffers, but do not show stale memory */
	memset(&map, 0, sizeof(map));
	map.handle = create.handle;
	if (drm_ioctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &map) == 0) {
		pixels = mmap(NULL, create.size, PROT_READ | PROT_WRITE,
			      MAP_SHARED, fd, (off_t)map.offset);
		if (pixels != MAP_FAILED) {
			memset(pixels, 0, create.size);
			munmap(pixels, create.size);
		}
	}

	memset(&fb, 0, sizeof(fb));
	fb.width = create.width;
	fb.height = create.height;
	fb.pitch = create.pitch;
	fb.bpp = 32;
	fb.depth = 24;
	fb.handle = create.handle;
	if (drm_ioctl(fd, DRM_IOCTL_MODE_ADDFB, &fb))
		return -1;
	*fb_id = fb.fb_id;
	return 0;
}

static int display_on(int fd, const struct output *out, uint32_t fb_id)
{
	struct drm_mode_crtc crtc;
	uint32_t connector = out->connector_id;

	memset(&crtc, 0, sizeof(crtc));
	crtc.crtc_id = out->crtc_id;
	crtc.fb_id = fb_id;
	crtc.set_connectors_ptr = (uintptr_t)&connector;
	crtc.count_connectors = 1;
	crtc.mode = out->mode;
	crtc.mode_valid = 1;
	return drm_ioctl(fd, DRM_IOCTL_MODE_SETCRTC, &crtc);
}

static int display_off(int fd, const struct output *out)
{
	struct drm_mode_crtc crtc;

	/* no framebuffer, no connectors and no mode disables the CRTC */
	memset(&crtc, 0, sizeof(crtc));
	crtc.crtc_id = out->crtc_id;
	return drm_ioctl(fd, DRM_IOCTL_MODE_SETCRTC, &crtc);
}

static void sleep_ms(long ms)
{
	struct timespec ts = { ms / 1000, (ms % 1000) * 1000000L };

	while (nanosleep(&ts, &ts) == -1 && errno == EINTR)
		;
}

int main(int argc, char **argv)
{
	struct output out;
	long off_ms = DEFAULT_OFF_MS;
	uint32_t fb_id;
	int fd, active;

	if (argc > 1) {
		char *end;

		off_ms = strtol(argv[1], &end, 10);
		if (*end || off_ms < 0 || off_ms > 10000) {
			fprintf(stderr, "usage: %s [off_ms (0-10000)]\n", argv[0]);
			return 2;
		}
	}

	memset(&out, 0, sizeof(out));
	fd = open_card(&out);
	if (fd < 0) {
		log_msg("no connected display found: %s", strerror(errno));
		return 1;
	}
	if (black_fb(fd, &out, &fb_id)) {
		log_msg("making a black frame failed: %s", strerror(errno));
		close(fd);
		return 1;
	}

	/*
	 * At boot the MediaTek driver keeps the bootloader's display running
	 * but reports the CRTC off. Turning it off then changes nothing, and
	 * the first "on" only takes the display over: the panel never powers
	 * down, and Zinitix touch stayed dead. So take it over first, and the
	 * off below powers the panel down.
	 */
	active = crtc_active(fd, out.crtc_id);
	if (active != 1) {
		log_msg("display reported %s, taking it over first",
			active == 0 ? "off" : "in an unknown state");
		if (display_on(fd, &out, fb_id)) {
			log_msg("taking the display over failed: %s", strerror(errno));
			close(fd);
			return 1;
		}
		sleep_ms(TAKEOVER_SETTLE_MS);
	}

	if (display_off(fd, &out)) {
		/* EACCES here means someone else, usually OrangeFox, is DRM master */
		log_msg("turning the display off failed: %s", strerror(errno));
		close(fd);
		return 1;
	}
	log_msg("display off for %ld ms", off_ms);
	sleep_ms(off_ms);

	if (display_on(fd, &out, fb_id)) {
		/* OrangeFox turns it on when it starts, so this is not fatal */
		log_msg("turning the display on failed: %s", strerror(errno));
		close(fd);
		return 1;
	}
	log_msg("display on");
	close(fd);
	return 0;
}
