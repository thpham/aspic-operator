from aiohttp import web

webservice = web.Application()

# health check
async def health(request):
  return web.Response(text="check")

webservice.router.add_route("GET", "/health", health)
