"""
Just feed pairs of

[<epoc date>, <value>]

and I will plot them on port 8888.
"""

import sys
import json

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
    'visible_points': '20',
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

def send_stdin():
    for i in sys.stdin:
        sys.stdout.write(i)
        buf.append(i)

        for w in websockets:
            try:
                w.write_message(i)
            except websocket.WebSocketClosedError:
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

application = tornado.web.Application([
    (r"/", MainHandler),
    (r'/websocket', StdinSocket),
])

if __name__ == "__main__":

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
