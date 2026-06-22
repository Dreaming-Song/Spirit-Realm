#!/usr/bin/env python3
"""灵境 · 一键启动服务端"""
import uvicorn

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8765, reload=True)
