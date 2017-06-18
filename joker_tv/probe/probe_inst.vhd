	component probe is
		port (
			probe  : in  std_logic_vector(510 downto 0) := (others => 'X'); -- probe
			source : out std_logic_vector(31 downto 0)                      -- source
		);
	end component probe;

	u0 : component probe
		port map (
			probe  => CONNECTED_TO_probe,  --  probes.probe
			source => CONNECTED_TO_source  -- sources.source
		);

