/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2013 Canonical Ltd
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Marco Trevisan <marco.trevisan@canonical.com>
 *          Mirco "MacSlow" Mueller <mirco.mueller@canonical.com>
 */

namespace CairoUtils
{

public void rounded_rectangle (Cairo.Context c, double x, double y,
                               double width, double height, double radius)
{
    var w = width - radius * 2;
    var h = height - radius * 2;
    var kappa = 0.5522847498 * radius;
    c.move_to (x + radius, y);
    c.rel_line_to (w, 0);
    c.rel_curve_to (kappa, 0, radius, radius - kappa, radius, radius);
    c.rel_line_to (0, h);
    c.rel_curve_to (0, kappa, kappa - radius, radius, -radius, radius);
    c.rel_line_to (-w, 0);
    c.rel_curve_to (-kappa, 0, -radius, kappa - radius, -radius, -radius);
    c.rel_line_to (0, -h);
    c.rel_curve_to (0, -kappa, radius - kappa, -radius, radius, -radius);
}

class GaussianBlur
{
    /* Gaussian Blur, based on Mirco Mueller work on notify-osd */

    public static void surface (Cairo.ImageSurface surface, uint radius, double sigma = 0.0f)
    {
        if (surface.get_format () != Cairo.Format.ARGB32)
        {
            warning ("Impossible to blur a non ARGB32-formatted ImageSurface");
            return;
        }

        surface.flush ();

        double radiusf = Math.fabs (radius) + 1.0f;

        if (sigma == 0.0f)
            sigma = Math.sqrt (-(radiusf * radiusf) / (2.0f * Math.log (1.0f / 255.0f)));

        int w = surface.get_width ();
        int h = surface.get_height ();
        int s = surface.get_stride ();

        // create pixman image for cairo image surface
        unowned uchar[] p = surface.get_data ();
        var src = new Pixman.Image.bits (Pixman.Format.A8R8G8B8, w, h, p, s);

        // attach gaussian kernel to pixman image
        var params = create_gaussian_blur_kernel ((int) radius, sigma);
        src.set_filter (Pixman.Filter.CONVOLUTION, params);

        // render blured image to new pixman image
        Pixman.Image.composite (Pixman.Operation.SRC, src, null, src,
                                0, 0, 0, 0, 0, 0, (uint16) w, (uint16) h);

        surface.mark_dirty ();
    }

    private static Pixman.Fixed[] create_gaussian_blur_kernel (int radius, double sigma)
    {
        double scale2 = 2.0f * sigma * sigma;
        double scale1 = 1.0f / (Math.PI * scale2);
        int size = 2 * radius + 1;
        int n_params = size * size;
        double sum = 0;

        var tmp = new double[n_params];

        // caluclate gaussian kernel in floating point format
        for (int i = 0, x = -radius; x <= radius; ++x)
        {
            for (int y = -radius; y <= radius; ++y, ++i)
            {
                double u = x * x;
                double v = y * y;

                tmp[i] = scale1 * Math.exp (-(u+v)/scale2);

                sum += tmp[i];
            }
        }

        // normalize gaussian kernel and convert to fixed point format
        var params = new Pixman.Fixed[n_params + 2];

        params[0] = Pixman.Fixed.int (size);
        params[1] = Pixman.Fixed.int (size);

        for (int i = 2; i < params.length; ++i)
            params[i] = Pixman.Fixed.double (tmp[i] / sum);

        return params;
    }
}

class ExponentialBlur
{
    /* Exponential Blur, based on the Nux version */

    const int APREC = 16;
    const int ZPREC = 7;

    public static void surface (Cairo.ImageSurface surface, int radius)
    {
        if (radius < 1)
            return;

        // before we mess with the surface execute any pending drawing
        surface.flush ();

        unowned uchar[] pixels = surface.get_data ();
        var width  = surface.get_width ();
        var height = surface.get_height ();
        var format = surface.get_format ();

        switch (format)
        {
            case Cairo.Format.ARGB32:
                blur (pixels, width, height, 4, radius);
                break;

            case Cairo.Format.RGB24:
                blur (pixels, width, height, 3, radius);
                break;

            case Cairo.Format.A8:
                blur (pixels, width, height, 1, radius);
                break;

            default :
                // do nothing
                break;
        }

        // inform cairo we altered the surfaces contents
        surface.mark_dirty ();
    }

    static void blur (uchar[] pixels, int width, int height, int channels, int radius)
    {
        // calculate the alpha such that 90% of
        // the kernel is within the radius.
        // (Kernel extends to infinity)

        int alpha = (int) ((1 << APREC) * (1.0f - Math.expf(-2.3f / (radius + 1.0f))));

        for (int row = 0; row < height; ++row)
          blurrow (pixels, width, height, channels, row, alpha);

        for (int col = 0; col < width; ++col)
          blurcol (pixels, width, height, channels, col, alpha);
    }

    static void blurrow (uchar[] pixels, int width, int height, int channels, int line, int alpha)
    {
        var scanline = &(pixels[line * width * channels]);

        int zR = *scanline << ZPREC;
        int zG = *(scanline + 1) << ZPREC;
        int zB = *(scanline + 2) << ZPREC;
        int zA = *(scanline + 3) << ZPREC;

        for (int index = 0; index < width; ++index)
        {
          blurinner (&scanline[index * channels], alpha, ref zR, ref zG, ref zB, ref zA);
        }

        for (int index = width - 2; index >= 0; --index)
        {
          blurinner (&scanline[index * channels], alpha, ref zR, ref zG, ref zB, ref zA);
        }
    }

    static void blurcol (uchar[] pixels, int width, int height, int channels, int x, int alpha)
    {
        var ptr = &(pixels[x * channels]);

        int zR = *ptr << ZPREC;
        int zG = *(ptr + 1) << ZPREC;
        int zB = *(ptr + 2) << ZPREC;
        int zA = *(ptr + 3) << ZPREC;

        for (int index = width; index < (height - 1) * width; index += width)
        {
            blurinner (&ptr[index * channels], alpha, ref zR, ref zG, ref zB, ref zA);
        }

        for (int index = (height - 2) * width; index >= 0; index -= width)
        {
            blurinner (&ptr[index * channels], alpha, ref zR, ref zG, ref zB, ref zA);
        }
    }

    static void blurinner (uchar *pixel, int alpha, ref int zR, ref int zG, ref int zB, ref int zA)
    {
        int R;
        int G;
        int B;
        uchar A;

        R = *pixel;
        G = *(pixel + 1);
        B = *(pixel + 2);
        A = *(pixel + 3);

        zR += (alpha * ((R << ZPREC) - zR)) >> APREC;
        zG += (alpha * ((G << ZPREC) - zG)) >> APREC;
        zB += (alpha * ((B << ZPREC) - zB)) >> APREC;
        zA += (alpha * ((A << ZPREC) - zA)) >> APREC;

        *pixel = zR >> ZPREC;
        *(pixel + 1) = zG >> ZPREC;
        *(pixel + 2) = zB >> ZPREC;
        *(pixel + 3) = zA >> ZPREC;
    }
}

}
