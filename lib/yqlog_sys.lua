require "log"
function yqdebug(szFmt, ...)
	log.debug(string.format(szFmt, ...))
end
function yqinfo(szFmt, ...)
	log.info(string.format(szFmt, ...))
end
function yqwarn(szFmt, ...)
	log.warning(string.format(szFmt, ...))
end
function yqerror(szFmt, ...)
	log.info(debug.traceback())
	log.error(string.format(szFmt, ...))
end
function yqassert(exp, szFmt, ...)
	if not exp then
		log.error(string.format(szFmt, ...))
		assert(exp)
	end	
end
