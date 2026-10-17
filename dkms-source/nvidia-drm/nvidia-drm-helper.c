/*
 * Copyright (c) 2016, NVIDIA CORPORATION. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

/*
 * This file contains snapshots of DRM helper functions from the
 * Linux kernel which are used by nvidia-drm.ko if the target kernel
 * predates the helper function.  Having these functions consistently
 * present simplifies nvidia-drm.ko source.
 */

#include "nvidia-drm-helper.h"

#if defined(NV_DRM_ATOMIC_MODESET_AVAILABLE)

#if defined(NV_DRM_DRMP_H_PRESENT)
#include <drm/drmP.h>
#endif

#if defined(NV_DRM_DRM_ATOMIC_UAPI_H_PRESENT)
#include <drm/drm_atomic_uapi.h>
#endif

/*
 * The inclusion of drm_framebuffer.h was removed from drm_crtc.h by commit
 * 720cf96d8fecde29b72e1101f8a567a0ce99594f ("drm: Drop drm_framebuffer.h from
 * drm_crtc.h") in linux-next, expected in v5.19-rc7.
 *
 * We only need drm_framebuffer.h for drm_framebuffer_put(), and it is always
 * present (v4.9+) when drm_framebuffer_{put,get}() is present (v4.12+), so it
 * is safe to unconditionally include it when drm_framebuffer_get() is present.
 */
#if defined(NV_DRM_FRAMEBUFFER_GET_PRESENT)
#include <drm/drm_framebuffer.h>
#endif

static void __nv_drm_framebuffer_put(struct drm_framebuffer *fb)
{
#if defined(NV_DRM_FRAMEBUFFER_GET_PRESENT)
    drm_framebuffer_put(fb);
#else
    drm_framebuffer_unreference(fb);
#endif

}

#endif /* NV_DRM_ATOMIC_MODESET_AVAILABLE */
