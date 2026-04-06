import asyncio
import websockets
import serial
import threading
import sys
import json
import re
import struct
import time

SERIAL_PORT = "/dev/ttyUSB1"
BAUD_RATE = 921600

clients = set()
ser = None
is_flashing = False  # 🚀 Global flag to pause UART during flashing

# Exploit Address Memory
jop_target_address = None
rop_target_address = None

ANSI_ESCAPE = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")
REG_PATTERN = re.compile(r"([a-zA-Z0-9_]+)\s*:\s*(0x[0-9A-Fa-f]+)")

GPR_NAMES = {
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1", "a0",
    "a1", "a2", "a3", "a4", "a5", "a6", "a7", "s2", "s3", "s4", "s5",
    "s6", "s7", "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6",
}
CSR_NAMES = {
    "mtvec", "mseccfg", "mcycle", "minstret", "ssp", "mscratch", "pmpcfg0", "pmpaddr0",
}


def serial_reader(loop):
    global ser, jop_target_address, rop_target_address, is_flashing
    
    stream_buffer = ""
    line_buffer = ""

    while True:
        # 🚀 If flashing is active, keep the port closed and wait
        if is_flashing:
            if ser and ser.is_open:
                try:
                    ser.close()
                except:
                    pass
            time.sleep(0.5)
            continue

        try:
            # Reconnect automatically if port is closed
            if ser is None or not ser.is_open:
                ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=0.01)
                print(f"[*] Connected to FPGA on {SERIAL_PORT} at {BAUD_RATE} baud.")

            while not is_flashing:
                if ser.in_waiting > 0:
                    raw_bytes = ser.read(ser.in_waiting)
                    chunk = raw_bytes.decode("utf-8", errors="ignore")

                    send_to_frontend(loop, "game", chunk)

                    stream_buffer += chunk
                    line_buffer += chunk

                    # SNOOPER LOGIC
                    if "\n" in line_buffer:
                        lines = line_buffer.split("\n")
                        for line in lines[:-1]:
                            clean_line = ANSI_ESCAPE.sub("", line)

                            match_jop = re.search(r"jop_landing target :\s*(0x)?([0-9a-fA-F]+)", clean_line)
                            if match_jop:
                                jop_target_address = int(match_jop.group(2), 16)
                                print(f"\n[\033[92m+\033[0m] Snooped JOP target: 0x{jop_target_address:x}")

                            match_rop = re.search(r"win_function target:\s*(0x)?([0-9a-fA-F]+)", clean_line)
                            if match_rop:
                                rop_target_address = int(match_rop.group(2), 16)
                                print(f"[\033[92m+\033[0m] Snooped ROP target: 0x{rop_target_address:x}")

                        line_buffer = lines[-1]
                        if len(line_buffer) > 1000:
                            line_buffer = line_buffer[-500:]

                    # DASHBOARD PARSER LOGIC
                    while "\x1b[s" in stream_buffer and "\x1b[u" in stream_buffer:
                        start_idx = stream_buffer.find("\x1b[s")
                        end_idx = stream_buffer.find("\x1b[u", start_idx)

                        if end_idx != -1:
                            frame = stream_buffer[start_idx:end_idx]
                            stream_buffer = stream_buffer[end_idx + 3 :]
                            clean_frame = ANSI_ESCAPE.sub(" ", frame)

                            matches = REG_PATTERN.findall(clean_frame)
                            for reg_name, hex_val in matches:
                                if reg_name in GPR_NAMES:
                                    send_to_frontend(loop, "telemetry", f"GPR:{reg_name}:{hex_val}")
                                elif reg_name in CSR_NAMES:
                                    send_to_frontend(loop, "telemetry", f"CSR:{reg_name}:{hex_val}")
                                elif reg_name.startswith("PTR_"):
                                    idx = reg_name.split("_")[1]
                                    send_to_frontend(loop, "telemetry", f"STK:{idx}:{hex_val}")
                        else:
                            break

                    if len(stream_buffer) > 10000:
                        stream_buffer = stream_buffer[-5000:]
                else:
                    # Small sleep to prevent 100% CPU usage while waiting for data
                    time.sleep(0.005)

        except Exception as e:
            # If the port is suddenly yanked or closed due to flashing, handle it gracefully
            if not is_flashing:
                print(f"\n[!] Serial Disconnected: {e}. Waiting to reconnect...")
            if ser:
                try: ser.close()
                except: pass
            ser = None
            time.sleep(1)


def send_to_frontend(loop, msg_type, data_str):
    if not data_str: return
    payload = json.dumps({"type": msg_type, "data": data_str})
    asyncio.run_coroutine_threadsafe(broadcast(payload), loop)


async def broadcast(message):
    for client in list(clients):
        try: await client.send(message)
        except websockets.exceptions.ConnectionClosed: clients.remove(client)


# 🚀 Async helper to safely flash the FPGA without freezing the dashboard
async def perform_flash(command):
    global is_flashing, ser
    is_flashing = True
    print(f"\n[*] Preparing to flash FPGA. Suspending UART...")
    
    # Wait half a second to let the serial_reader thread yield and close the port
    await asyncio.sleep(0.5) 
    
    print(f"[*] Executing: {command}")
    
    # Run the flash command completely asynchronously
    process = await asyncio.create_subprocess_shell(command)
    await process.communicate() # This waits for openFPGALoader to finish!
    
    print("[*] Flashing completed! Resuming UART connection...\n")
    is_flashing = False


async def ws_handler(websocket):
    global jop_target_address, rop_target_address, is_flashing
    clients.add(websocket)
    print(f"[*] Dashboard connected! (Active viewers: {len(clients)})")

    try:
        async for message in websocket:
            
            # 🚀 FIX 1: Intercept the MOD message from React so it doesn't break the JSON parser
            if message.startswith("MOD:"):
                print(f"[*] Frontend switched module to: {message[4:]}")
                continue

            # Handle JSON command signals
            if not message.startswith("KEY:"):
                try:
                    cmd_data = json.loads(message)
                    if cmd_data.get("type") == "command":
                        target = cmd_data.get("data")
                        print(f"[!] COMMAND TRIGGERED: {target}")

                        # 🚀 FIX 2: Remove the "../" since you are running the script from the project root
                        if target == "upload_pong":
                            await perform_flash("openFPGALoader -c ft2232 -b tangprimer20k bitstreams/pong/soc.fs")
                        elif target == "upload_tetris":
                            await perform_flash("openFPGALoader -c ft2232 -b tangprimer20k bitstreams/tetris/soc.fs")
                        elif target == "upload_safe":
                            await perform_flash("openFPGALoader -c ft2232 -b tangprimer20k bitstreams/cfi_safe/soc.fs")
                        elif target == "upload_unsafe":
                            await perform_flash("openFPGALoader -c ft2232 -b tangprimer20k bitstreams/cfi_unsafe/soc.fs")

                        # EXPLOIT COMMANDS
                        elif target == "exploit_jop":
                            if not ser or not ser.is_open or is_flashing:
                                print("[!] ERROR: UART not ready.")
                                continue
                            if jop_target_address is None:
                                print("[!] ERROR: Target address not snooped yet!")
                                continue

                            print(f"[\033[93m*\033[0m] Injecting JOP Payload -> 0x{jop_target_address:x}")
                            payload = b"A" * 16 + struct.pack("<I", jop_target_address) + b"\n"
                            ser.write(payload)
                            ser.flush()

                        elif target == "exploit_rop":
                            if not ser or not ser.is_open or is_flashing:
                                print("[!] ERROR: UART not ready.")
                                continue
                            if rop_target_address is None:
                                print("[!] ERROR: Target address not snooped yet!")
                                continue

                            print(f"[\033[93m*\033[0m] Injecting ROP Stack Smash -> 0x{rop_target_address:x}")
                            payload = b"A" * 16
                            for _ in range(24):
                                payload += struct.pack("<I", rop_target_address)
                            payload += b"\n"
                            ser.write(payload)
                            ser.flush()
                        else:
                            # Run safe generic commands without killing serial
                            proc = await asyncio.create_subprocess_shell(target)
                            await proc.communicate()
                            
                        continue
                except Exception as e:
                    print(f"Error handling command: {e}")
                    pass

            # 2. Safety block for game keys during a flash
            if not ser or not ser.is_open or is_flashing:
                continue

            # 3. Handle standard game keys
            if message.startswith("KEY:"):
                char_to_send = message[4:]
                ser.write(char_to_send.encode("utf-8"))
                ser.flush()

    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        clients.remove(websocket)
        print(f"[*] Dashboard disconnected. (Remaining viewers: {len(clients)})")


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
