
export function console(line, level) {
  try {
    line = JSON.parse(line)
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
