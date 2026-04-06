import asyncio
import websockets
import serial
import threading
import sys
import json
import re

SERIAL_PORT = "/dev/ttyUSB2"
BAUD_RATE = 921600

clients = set()
ser = None

# Regex to strip ALL ANSI codes (colors, cursor positions like \x1B[6;120H, etc.)
ANSI_ESCAPE = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")
# Regex to match "register_name : 0x1234ABCD"
REG_PATTERN = re.compile(r"([a-zA-Z0-9_]+)\s*:\s*(0x[0-9A-Fa-f]+)")

# Lookup tables to know where to route the data
GPR_NAMES = {
    "zero",
    "ra",
    "sp",
    "gp",
    "tp",
    "t0",
    "t1",
    "t2",
    "s0",
    "s1",
    "a0",
    "a1",
    "a2",
    "a3",
    "a4",
    "a5",
    "a6",
    "a7",
    "s2",
    "s3",
    "s4",
    "s5",
    "s6",
    "s7",
    "s8",
    "s9",
    "s10",
    "s11",
    "t3",
    "t4",
    "t5",
    "t6",
}
CSR_NAMES = {
    "mtvec",
    "mseccfg",
    "mcycle",
    "minstret",
    "ssp",
    "mscratch",
    "pmpcfg0",
    "pmpaddr0",
}


def serial_reader(loop):
    global ser
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=0.01)
        print(f"[*] Connected to FPGA on {SERIAL_PORT} at {BAUD_RATE} baud.")

        stream_buffer = ""

        while True:
            if ser.in_waiting > 0:
                raw_bytes = ser.read(ser.in_waiting)
                chunk = raw_bytes.decode("utf-8", errors="ignore")

                # 1. Forward EVERYTHING instantly to xterm.js (Zero Latency Game Feed)
                send_to_frontend(loop, "game", chunk)

                # 2. Append to our parser buffer
                stream_buffer += chunk

                # 3. Look for a complete Dashboard Frame bounded by Save/Restore Cursor
                while "\x1b[s" in stream_buffer and "\x1b[u" in stream_buffer:
                    start_idx = stream_buffer.find("\x1b[s")
                    end_idx = stream_buffer.find("\x1b[u", start_idx)

                    if end_idx != -1:
                        # Extract the exact block containing the dashboard update
                        frame = stream_buffer[start_idx:end_idx]

                        # Remove this frame from the buffer (including the \x1B[u)
                        stream_buffer = stream_buffer[end_idx + 3 :]

                        # Strip all ANSI grid coordinates and colors
                        # This turns "\x1B[22;120H\033[1;36mmepc\033[0m: 0x800000A0" into "mepc: 0x800000A0"
                        clean_frame = ANSI_ESCAPE.sub("", frame)

                        # Find all cleanly extracted register-value pairs
                        matches = REG_PATTERN.findall(clean_frame)
                        for reg_name, hex_val in matches:
                            if reg_name in GPR_NAMES:
                                send_to_frontend(
                                    loop, "telemetry", f"GPR:{reg_name}:{hex_val}"
                                )
                            elif reg_name in CSR_NAMES:
                                send_to_frontend(
                                    loop, "telemetry", f"CSR:{reg_name}:{hex_val}"
                                )
                            elif reg_name.startswith("PTR_"):
                                idx = reg_name.split("_")[1]
                                send_to_frontend(
                                    loop, "telemetry", f"STK:{idx}:{hex_val}"
                                )
                    else:
                        # Malformed frame (missing end tag), break and wait for more data
                        break

                # Safety feature: Prevent memory leak if terminal data gets huge without cursor tags
                if len(stream_buffer) > 10000:
                    stream_buffer = stream_buffer[-5000:]

    except serial.SerialException as e:
        print(f"\n[!] ERROR: Could not open {SERIAL_PORT}.")
        sys.exit(1)


def send_to_frontend(loop, msg_type, data_str):
    if not data_str:
        return

    payload = json.dumps({"type": msg_type, "data": data_str})
    asyncio.run_coroutine_threadsafe(broadcast(payload), loop)


async def broadcast(message):
    for client in list(clients):
        try:
            await client.send(message)
        except websockets.exceptions.ConnectionClosed:
            clients.remove(client)


async def ws_handler(websocket):
    clients.add(websocket)
    print(f"[*] Dashboard connected! (Active viewers: {len(clients)})")
    try:
        async for message in websocket:
            if not ser or not ser.is_open:
                continue

            if message.startswith("KEY:"):
                char_to_send = message[4:]
                ser.write(char_to_send.encode("utf-8"))
                ser.flush()

    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        clients.remove(websocket)
        print("[*] Dashboard disconnected.")


async def main():
    loop = asyncio.get_running_loop()
    thread = threading.Thread(target=serial_reader, args=(loop,), daemon=True)
    thread.start()

    async with websockets.serve(ws_handler, "localhost", 8081):
        print("[*] WebSocket Bridge running on ws://localhost:8081")
        await asyncio.Future()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[*] Bridge shut down.")
