require 'spec_helper'

RSpec.describe 'Screenshots' do
  describe 'Page#screenshot' do
    include Utils::Golden

    sinatra do
      get('/grid.html') do
        <<~HTML
        <script>
        document.addEventListener('DOMContentLoaded', function() {
            function generatePalette(amount) {
                var result = [];
                var hueStep = 360 / amount;
                for (var i = 0; i < amount; ++i)
                    result.push('hsl(' + (hueStep * i) + ', 100%, 90%)');
                return result;
            }

            var palette = generatePalette(100);
            for (var i = 0; i < 200; ++i) {
                var box = document.createElement('div');
                box.classList.add('box');
                box.style.setProperty('background-color', palette[i % palette.length]);
                var x = i;
                do {
                    var digit = x % 10;
                    x = (x / 10)|0;
                    var span = document.createElement('span');
                    span.innerText = digit;
                    box.insertBefore(span, box.firstChild);
                } while (x);
                document.body.appendChild(box);
            }
        });
        </script>

        <style>

        body {
            margin: 0;
            padding: 0;
        }

        .box {
            font-family: arial;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            margin: 0;
            padding: 0;
            width: 50px;
            height: 50px;
            box-sizing: border-box;
            border: 1px solid darkgray;
        }

        ::-webkit-scrollbar {
            display: none;
        }
        </style>
        HTML
      end
    end

    before {
      page.viewport = Puppeteer::Viewport.new(width: 500, height: 500)
      page.goto('http://127.0.0.1:4567/grid.html')
    }

    it 'should work' do
      expect(image_from(page.screenshot)).to eq(golden('screenshot-sanity.png'))
    end

    it 'should clip rect' do
      screenshot = page.screenshot(
        clip: {
          x: 50,
          y: 100,
          width: 150,
          height: 100,
        },
      )
      expect(image_from(screenshot)).to eq(golden('screenshot-clip-rect.png'))
    end

    it 'should clip elements to the viewport' do
      screenshot = page.screenshot(
        clip: {
          x: 50,
          y: 600,
          width: 100,
          height: 100,
        },
      )
      expect(image_from(screenshot)).to eq(golden('screenshot-offscreen-clip.png'))
    end

    it 'should run in parallel' do
      promises = 3.times.map do |index|
        future(index) { |i|
          page.screenshot(
            clip: {
              x: 50 * i,
              y: 0,
              width: 50,
              height: 50,
            },
          )
        }
      end
      screenshots = await_all(*promises)
      expect(image_from(screenshots[1])).to eq(golden('grid-cell-1.png'))
    end

    it 'should take fullPage screenshots' do
      screenshot = page.screenshot(full_page: true)
      expect(image_from(screenshot)).to eq(golden('screenshot-grid-fullpage.png'))
    end

    # it('should run in parallel in multiple pages', async () => {
    #   const { server, context } = getTestState();

    #   const N = 2;
    #   const pages = await Promise.all(
    #     Array(N)
    #       .fill(0)
    #       .map(async () => {
    #         const page = await context.newPage();
    #         await page.goto(server.PREFIX + '/grid.html');
    #         return page;
    #       })
    #   );
    #   const promises = [];
    #   for (let i = 0; i < N; ++i)
    #     promises.push(
    #       pages[i].screenshot({
    #         clip: { x: 50 * i, y: 0, width: 50, height: 50 },
    #       })
    #     );
    #   const screenshots = await Promise.all(promises);
    #   for (let i = 0; i < N; ++i)
    #     expect(screenshots[i]).toBeGolden(`grid-cell-${i}.png`);
    #   await Promise.all(pages.map((page) => page.close()));
    # });
    # itFailsFirefox('should allow transparency', async () => {
    #   const { page, server } = getTestState();

    #   await page.setViewport({ width: 100, height: 100 });
    #   await page.goto(server.EMPTY_PAGE);
    #   const screenshot = await page.screenshot({ omitBackground: true });
    #   expect(screenshot).toBeGolden('transparent.png');
    # });
    # itFailsFirefox('should render white background on jpeg file', async () => {
    #   const { page, server } = getTestState();

    #   await page.setViewport({ width: 100, height: 100 });
    #   await page.goto(server.EMPTY_PAGE);
    #   const screenshot = await page.screenshot({
    #     omitBackground: true,
    #     type: 'jpeg',
    #   });
    #   expect(screenshot).toBeGolden('white.jpg');
    # });
    # it('should work with odd clip size on Retina displays', async () => {
    #   const { page } = getTestState();

    #   const screenshot = await page.screenshot({
    #     clip: {
    #       x: 0,
    #       y: 0,
    #       width: 11,
    #       height: 11,
    #     },
    #   });
    #   expect(screenshot).toBeGolden('screenshot-clip-odd-size.png');
    # });
    # itFailsFirefox('should return base64', async () => {
    #   const { page, server } = getTestState();

    #   await page.setViewport({ width: 500, height: 500 });
    #   await page.goto(server.PREFIX + '/grid.html');
    #   const screenshot = await page.screenshot({
    #     encoding: 'base64',
    #   });
    #   // TODO (@jackfranklin): improve the screenshot types.
    #   // - if we pass encoding: 'base64', it returns a string
    #   // - else it returns a buffer.
    #   // If we can fix that we can avoid this "as string" here.
    #   expect(Buffer.from(screenshot as string, 'base64')).toBeGolden(
    #     'screenshot-sanity.png'
    #   );
    # });
  end

  # describe('ElementHandle.screenshot', function () {
  #   it('should work', async () => {
  #     const { page, server } = getTestState();

  #     await page.setViewport({ width: 500, height: 500 });
  #     await page.goto(server.PREFIX + '/grid.html');
  #     await page.evaluate(() => window.scrollBy(50, 100));
  #     const elementHandle = await page.$('.box:nth-of-type(3)');
  #     const screenshot = await elementHandle.screenshot();
  #     expect(screenshot).toBeGolden('screenshot-element-bounding-box.png');
  #   });
  #   it('should take into account padding and border', async () => {
  #     const { page } = getTestState();

  #     await page.setViewport({ width: 500, height: 500 });
  #     await page.setContent(`
  #       something above
  #       <style>div {
  #         border: 2px solid blue;
  #         background: green;
  #         width: 50px;
  #         height: 50px;
  #       }
  #       </style>
  #       <div></div>
  #     `);
  #     const elementHandle = await page.$('div');
  #     const screenshot = await elementHandle.screenshot();
  #     expect(screenshot).toBeGolden('screenshot-element-padding-border.png');
  #   });
  #   it('should capture full element when larger than viewport', async () => {
  #     const { page } = getTestState();

  #     await page.setViewport({ width: 500, height: 500 });

  #     await page.setContent(`
  #       something above
  #       <style>
  #       div.to-screenshot {
  #         border: 1px solid blue;
  #         width: 600px;
  #         height: 600px;
  #         margin-left: 50px;
  #       }
  #       ::-webkit-scrollbar{
  #         display: none;
  #       }
  #       </style>
  #       <div class="to-screenshot"></div>
  #     `);
  #     const elementHandle = await page.$('div.to-screenshot');
  #     const screenshot = await elementHandle.screenshot();
  #     expect(screenshot).toBeGolden(
  #       'screenshot-element-larger-than-viewport.png'
  #     );

  #     expect(
  #       await page.evaluate(() => ({
  #         w: window.innerWidth,
  #         h: window.innerHeight,
  #       }))
  #     ).toEqual({ w: 500, h: 500 });
  #   });
  #   it('should scroll element into view', async () => {
  #     const { page } = getTestState();

  #     await page.setViewport({ width: 500, height: 500 });
  #     await page.setContent(`
  #       something above
  #       <style>div.above {
  #         border: 2px solid blue;
  #         background: red;
  #         height: 1500px;
  #       }
  #       div.to-screenshot {
  #         border: 2px solid blue;
  #         background: green;
  #         width: 50px;
  #         height: 50px;
  #       }
  #       </style>
  #       <div class="above"></div>
  #       <div class="to-screenshot"></div>
  #     `);
  #     const elementHandle = await page.$('div.to-screenshot');
  #     const screenshot = await elementHandle.screenshot();
  #     expect(screenshot).toBeGolden(
  #       'screenshot-element-scrolled-into-view.png'
  #     );
  #   });
  #   itFailsFirefox('should work with a rotated element', async () => {
  #     const { page } = getTestState();

  #     await page.setViewport({ width: 500, height: 500 });
  #     await page.setContent(`<div style="position:absolute;
  #                                       top: 100px;
  #                                       left: 100px;
  #                                       width: 100px;
  #                                       height: 100px;
  #                                       background: green;
  #                                       transform: rotateZ(200deg);">&nbsp;</div>`);
  #     const elementHandle = await page.$('div');
  #     const screenshot = await elementHandle.screenshot();
  #     expect(screenshot).toBeGolden('screenshot-element-rotate.png');
  #   });
  #   itFailsFirefox('should fail to screenshot a detached element', async () => {
  #     const { page } = getTestState();

  #     await page.setContent('<h1>remove this</h1>');
  #     const elementHandle = await page.$('h1');
  #     await page.evaluate(
  #       (element: HTMLElement) => element.remove(),
  #       elementHandle
  #     );
  #     const screenshotError = await elementHandle
  #       .screenshot()
  #       .catch((error) => error);
  #     expect(screenshotError.message).toBe(
  #       'Node is either not visible or not an HTMLElement'
  #     );
  #   });
  #   it('should not hang with zero width/height element', async () => {
  #     const { page } = getTestState();

  #     await page.setContent('<div style="width: 50px; height: 0"></div>');
  #     const div = await page.$('div');
  #     const error = await div.screenshot().catch((error_) => error_);
  #     expect(error.message).toBe('Node has 0 height.');
  #   });
  #   it('should work for an element with fractional dimensions', async () => {
  #     const { page } = getTestState();

  #     await page.setContent(
  #       '<div style="width:48.51px;height:19.8px;border:1px solid black;"></div>'
  #     );
  #     const elementHandle = await page.$('div');
  #     const screenshot = await elementHandle.screenshot();
  #     expect(screenshot).toBeGolden('screenshot-element-fractional.png');
  #   });
  #   itFailsFirefox('should work for an element with an offset', async () => {
  #     const { page } = getTestState();

  #     await page.setContent(
  #       '<div style="position:absolute; top: 10.3px; left: 20.4px;width:50.3px;height:20.2px;border:1px solid black;"></div>'
  #     );
  #     const elementHandle = await page.$('div');
  #     const screenshot = await elementHandle.screenshot();
  #     expect(screenshot).toBeGolden('screenshot-element-fractional-offset.png');
  #   });
  # });
end
