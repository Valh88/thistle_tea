defmodule ThistleTea.Game.Login do
  defmacro __using__(_) do
    quote do
      alias ThistleTea.CharacterStorage
      alias ThistleTea.DBC
      alias ThistleTea.PlayerStorage

      import ThistleTea.Game.UpdateObject
      import Bitwise, only: [<<<: 2, |||: 2]
      import ThistleTea.Util, only: [pack_guid: 1]

      @cmsg_player_login 0x03D
      @smsg_login_verify_world 0x236
      @smsg_account_data_times 0x209
      @smsg_set_rest_start 0x21E
      @smsg_bindpointupdate 0x155
      @smsg_tutorial_flags 0x0FD
      @smsg_login_settimespeed 0x042
      @smsg_trigger_cinematic 0x0FA

      @impl GenServer
      def handle_cast({:handle_packet, @cmsg_player_login, _size, body}, {socket, state}) do
        <<character_guid::little-size(64)>> = body
        Logger.info("[GameServer] CMSG_PLAYER_LOGIN: character_guid: #{character_guid}")

        c = CharacterStorage.get_by_guid(state.username, character_guid)

        Logger.info("[GameServer] Character: #{inspect(c)}")

        {:ok, player_pid} = PlayerStorage.start_link(%{character: c})
        state = Map.put(state, :player_pid, player_pid)

        send_packet(
          @smsg_login_verify_world,
          <<c.map::little-size(32), c.x::little-float-size(32), c.y::little-float-size(32),
            c.z::little-float-size(32), c.orientation::little-float-size(32)>>
        )

        # needed for no white chatbox + keybinds
        send_packet(
          @smsg_account_data_times,
          <<0::little-size(128)>>
        )

        # maybe useless? mangos sends it, though
        send_packet(
          @smsg_set_rest_start,
          <<0::little-size(32)>>
        )

        # SMSG_BINDPOINTUPDATE
        # let's just init it to character's position for now
        send_packet(
          @smsg_bindpointupdate,
          <<c.map::little-size(32), c.x::little-float-size(32), c.y::little-float-size(32),
            c.z::little-float-size(32), c.orientation::little-float-size(32),
            c.map::little-size(32), c.area::little-size(32)>>
        )

        # no tutorials
        send_packet(@smsg_tutorial_flags, <<0xFFFFFFFFFFFFFFFF::little-size(256)>>)

        # send initial spells
        # send initial action buttons
        # send initial repuations

        # SMSG_LOGIN_SETTIMESPEED
        # TODO: verify this
        dt = DateTime.utc_now()

        date =
          (dt.year - 100) <<< 24 ||| dt.month <<< 20 ||| (dt.day - 1) <<< 14 |||
            Date.day_of_week(dt) <<< 11 ||| dt.hour <<< 6 ||| dt.minute

        send_packet(
          @smsg_login_settimespeed,
          <<date::little-size(32), 0.01666667::little-float-size(32)>>
        )

        chr_race = DBC.get_by(ChrRaces, id: c.race)

        # SMSG_TRIGGER_CINEMATIC
        if false do
          send_packet(
            @smsg_trigger_cinematic,
            <<chr_race.cinematic_sequence::little-size(32)>>
          )
        end

        unit_display_id =
          case(c.gender) do
            0 -> chr_race.male_display
            1 -> chr_race.female_display
          end

        mb = %{
          # what is 0x71?: SELF ||| ALL ||| LIVING ||| HAS_POSITION
          update_flag: 0x71,
          movement_flags: 0,
          position: {c.x, c.y, c.z, c.orientation},
          fall_time: 0.0,
          walk_speed: 1.0,
          run_speed: 7.0,
          run_back_speed: 4.5,
          swim_speed: 0.0,
          swim_back_speed: 0.0,
          turn_rate: 3.1415
        }

        fields = %{
          object_guid: c.guid,
          object_type: 25,
          object_scale_x: 1.0,
          unit_health: 100,
          unit_power_1: 100,
          unit_power_2: 100,
          unit_power_3: 100,
          unit_power_4: 100,
          unit_power_5: 100,
          unit_max_health: 100,
          unit_max_power_1: 100,
          unit_max_power_2: 100,
          unit_max_power_3: 100,
          unit_max_power_4: 100,
          unit_max_power_5: 100,
          unit_level: c.level,
          unit_faction_template: 1,
          unit_bytes_0: <<c.race, c.class, c.gender, 1>>,
          unit_display_id: unit_display_id,
          unit_native_display_id: unit_display_id,
          player_flags: 0,
          player_features: <<c.skin, c.face, c.hairstyle, c.haircolor>>,
          player_xp: 1,
          player_next_level_xp: 100,
          player_rest_state_experience: 100
        }

        packed_guid = pack_guid(c.guid)
        movement_block = encode_movement_block(mb)
        mask_count = mask_blocks_count(fields)
        mask = generate_mask(fields)
        objects = generate_objects(fields)

        packet =
          <<
            # amount_of_objects
            1::little-size(32),
            # has transport
            0
          >> <>
            <<
              # object start, there can be mulitple
              # update_type = CREATE_NEW_OBJECT2
              3
            >> <>
            packed_guid <>
            <<
              # object type
              4
            >> <>
            movement_block <>
            <<mask_count>> <>
            mask <>
            objects

        send_update_packet(packet)

        {:noreply, {socket, state}}
      end
    end
  end
end
