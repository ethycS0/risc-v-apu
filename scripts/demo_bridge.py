import asyncio
import websockets
import serial
import threading
import sys

SERIAL_PORT = "/dev/ttyUSB1"
BAUD_RATE = 921600

clients = set()
ser = None

def serial_reader(loop):
    global ser
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=0.01)
        print(f"[*] Connected to FPGA on {SERIAL_PORT} at {BAUD_RATE} baud.")

        while True:
            if ser.in_waiting > 0:
                raw_bytes = ser.read(ser.in_waiting)
                data_str = raw_bytes.decode("utf-8", errors="ignore")

                if clients and data_str:
                    asyncio.run_coroutine_threadsafe(broadcast(data_str), loop)

    except serial.SerialException as e:
        print(f"\n[!] ERROR: Could not open {SERIAL_PORT}.")
        sys.exit(1)


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
