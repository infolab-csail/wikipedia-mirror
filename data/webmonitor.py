"""
Just feed pairs of

<epoc date> <float value>

or even just

<float value>

One way to do that would be

    $ <cmd> stdbuf -oL awk "{print \$1/$$max}" | python webmonitor.py

and I will plot them on port 8888. This will also pipe the input right
out to the output. Strange input will be ignored and piped this way,
but this needs to be done by awk aswell in the above example.
"""

import sys
import json
import time

from threading import Thread
from collections import deque

import tornado.websocket as websocket
import tornado.ioloop
import tornado.web

HTML = """
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <title>DrNinjaBatmans Websockets</title>

    <script type="text/javascript" src="http://code.jquery.com/jquery-1.10.1.js"></script>
    <script type="text/javascript" src="http://code.highcharts.com/highcharts.js"></script>

    <script>
var chart; // global
var url = location.hostname + ':' + (parseInt(location.port));
var ws = new WebSocket('ws://' + url + '/websocket');
ws.onmessage = function(msg) {
    add_point(msg.data);
};

// ws.onclose = function() { alert('Connection closed.'); };

var add_point = function(point) {
    var series = chart.series[0],
	shift = series.data.length > %d;
    chart.series[0].addPoint(eval(point), true, shift);
};

$(document).ready(function() {
    chart = new Highcharts.Chart(JSON.parse('%s'));
});
    </script>

  </head><body><div id="container" style="width: 800px; height: 400px; margin: 0 auto"></div></body></html>
"""

config = {
    'visible_points': 10,
    'py_chart_opts': { 'chart': { 'renderTo': 'container',
                                  'defaultSeriesType': 'spline'},
                       'title': { 'text': 'DrNinjaBatmans data'},
                       'xAxis': { 'type': 'datetime',
                                  'tickPixelInterval': '150'},
                       'yAxis': { 'minPadding': 0.2,
                                  'maxPadding': 0.2,
                                  'title': {'text': 'Value',
                                            'margin': 80}
                              },
                       'series': [{ 'name': 'Data',
                                    'data': []}]}

}

def date_float(s):
    try:
        date, val = s.split()
    except ValueError:
        val = s.strip()
        date = time.time()

    return int(date), float(val)


def send_stdin(fn=date_float):
    for raw in sys.stdin:
        sys.stdout.write(raw)

        # Ignore strange input.
        try:
            jsn = json.dumps(fn(raw))

            buf.append(jsn)

            for w in websockets:
                try:
                    w.write_message(jsn)
                except websocket.WebSocketClosedError:
                    pass

        except:
            pass

    for ws in websockets:
        ws.close()

class StdinSocket(websocket.WebSocketHandler):
    def open(self):
        for i in buf:
            self.write_message(i)

        websockets.append(self)


    def closs(self):
        websockets.remove(self)

class MainHandler(tornado.web.RequestHandler):
    def get(self):
        self.write(HTML % (int(config['visible_points']),
                           json.dumps(config['py_chart_opts'])))


if __name__ == "__main__":
    application = tornado.web.Application([
        (r"/", MainHandler),
        (r'/websocket', StdinSocket),
    ])
    buf = deque(maxlen=int(config['visible_points']))
    websockets = []


    config['args'] = []
    for a in sys.argv[1:]:
        if '=' in a:
            k, v = a.split('=', 1)
            config[k] = v
        else:
            config['args'].append(a)

    Thread(target=send_stdin).start()
    application.listen(8888)
    tornado.ioloop.IOLoop.instance().start()
