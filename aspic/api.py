from aiohttp import web

webservice = web.Application()

# Ping
async def ping(request):
  return web.Response(text="pong")

webservice.router.add_route("GET", "/ping", ping)
