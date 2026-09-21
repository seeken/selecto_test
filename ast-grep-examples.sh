#!/bin/bash
# AST-Grep Examples for Selecto Test Project

echo "=== AST-Grep Examples for Selecto Test Project ==="
echo ""

echo "1. Find all Mix.env() usage (potential production issues):"
echo "   ast-grep --pattern 'Mix.env()' lib/ vendor/"
echo ""

echo "2. Find all Selecto.execute calls:"
echo "   ast-grep --pattern 'Selecto.execute(\$\$\$)' --lang elixir vendor/"
echo ""

echo "3. Find all error tuples:"
echo "   ast-grep --pattern '{:error, \$ERROR}' --lang elixir lib/"
echo ""

echo "4. Find all LiveView mount functions:"
echo "   ast-grep --pattern 'def mount(\$\$\$PARAMS, \$SESSION, \$SOCKET) do \$\$\$BODY end' --lang elixir lib/"
echo ""

echo "5. Find all Phoenix hooks definitions:"
echo "   ast-grep --pattern 'hooks: {\$\$\$}' --lang javascript assets/"
echo ""

echo "6. Find all custom columns in Selecto:"
echo "   ast-grep --pattern 'Selecto.custom_column(\$\$\$)' --lang elixir lib/"
echo ""

echo "7. Find all Ecto queries:"
echo "   ast-grep --pattern 'from(\$VAR in \$SCHEMA, \$\$\$)' --lang elixir lib/"
echo ""

echo "8. Find rescue blocks (error handling):"
echo "   ast-grep --pattern 'rescue \$\$\$' --lang elixir vendor/"
echo ""

echo "=== Running example: Finding Mix.env() usage ==="
ast-grep --pattern 'Mix.env()' lib/ ../selecto_views/lib/ | head -10
