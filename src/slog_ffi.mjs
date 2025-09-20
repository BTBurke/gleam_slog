// FFI for console logging
// In the browser, it uses console.{info, warn, error} methods
// For server runtimes (Node, Deno, Bun), it uses the global console.log

// log to stdout on server, to the console in the browser
export function console(line, level) {
  const runtime = detect_runtime();
  switch (runtime) {
    case "browser":
      console_browser(line, level);
      break;
    default:
      console.log(line);
  }
}

// log to stderr on server, to the console on browser
export function console_error(line, level) {
  const runtime = detect_runtime();
  switch (runtime) {
    case "browser":
      console_browser(line, level);
      break;
    default:
      console.error(line);
  }
}


function console_browser(line, level) {
  try {
    line = JSON.parse(line);
  } catch (e) { }
  switch (level) {
    case "INFO":
      console.info(line);
      break;
    case "WARN":
      console.warn(line);
      break;
    case "ERROR":
      console.error(line);
      break;
    default:
      console.log(line);
  }
}

function detect_runtime() {
  if (globalThis.process?.release?.name === undefined) {
    return "browser";
  }
  // running in JS server runtime
  if (globalThis.Bun) {
    return "bun";
  }
  if (globalThis.Deno) {
    return "deno";
  }
  return "node";
}
