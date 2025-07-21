
# --- 1. Setup Database and Extensions ---
echo "--- Setting up PostgreSQL database and extensions ---"

cd /tmp
git clone --branch v0.8.0 https://github.com/pgvector/pgvector.git
cd pgvector
make clean
make
sudo make install



